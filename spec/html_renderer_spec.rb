# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "digest"
require "open3"

describe AwsSecurityViz::Renderer::Html do
  let(:hostile) { %(<img src=x onerror="window.pwned=1"></script><script>window.pwned=2</script>) }
  let(:config) { AwsSecurityViz::AwsConfig.new({}) }
  let(:vendor) { File.expand_path("../lib/aws_security_viz/vendor/cytoscape", __dir__) }

  let(:fcose_files) { %w[layout-base/layout-base.js cose-base/cose-base.js fcose/cytoscape-fcose.js] }

  around { |ex| Dir.mktmpdir { |dir| Dir.chdir(dir) { ex.run } } }

  def render(file = "report.html")
    renderer = described_class.new(file, config)
    renderer.add_node("sg-web", {label: "web", vpc_id: "vpc-1", region: "eu-west-1"})
    renderer.add_node("sg-db", {label: "db", vpc_id: "vpc-1", region: "eu-west-1", unused: true})
    renderer.add_node("sg-evil", {label: hostile, vpc_id: "vpc-2", region: "us-east-1"})
    renderer.add_node("0.0.0.0/0", {label: "0.0.0.0/0"})
    renderer.add_edge("sg-web", "sg-db", {color: :blue, label: "5432", descriptions: [{ports: "5432", text: "app -> #{hostile}"}]})
    renderer.add_edge("0.0.0.0/0", "sg-web", {color: :blue, label: "22", risky: true})
    renderer.add_edge("sg-evil", "sg-web", {color: :red, label: "all"})
    renderer.output
    File.read(file)
  end

  it "writes a single file with inlined library and data and no external references" do
    html = render
    expect(Dir.children(".")).to eq(["report.html"])
    expect(html).to include(File.read(File.join(vendor, "cytoscape.min.js")))
    fcose_files.each { |file| expect(html).to include(File.read(File.join(vendor, "..", file))) }
    expect(html).not_to match(/<script[^>]*\ssrc=/i)
    expect(html).not_to match(/<link[^>]*href=/i)
    expect(html).not_to include("/*DATA*/", "/*CYTOSCAPE*/")
  end

  it "cannot be broken out of by data: markup characters never appear raw in the data block" do
    html = render
    data = html[%r{<script type="application/json" id="graph-data">(.*?)</script>}m, 1]
    expect(data).not_to include("<")
    parsed = JSON.parse(data)
    expect(parsed["nodes"].map { |n| n["label"] }).to include(hostile)
    expect(parsed["edges"].map { |e| e["kind"] }).to eq(%w[ingress ingress egress])
    expect(parsed["nodes"].first).to include("vpc" => "vpc-1", "region" => "eu-west-1")
  end

  it "never assigns data through innerHTML or similar" do
    template = File.read(described_class::TEMPLATE)
    expect(template).not_to match(/innerHTML|outerHTML|insertAdjacentHTML|document\.write|eval\(/)
  end

  it "keeps the vendored Cytoscape.js pinned, licensed and documented" do
    readme = File.read(File.join(vendor, "README.md"))
    expect(File.read(File.join(vendor, "LICENSE"))).to include("Permission is hereby granted, free of charge")
    expect(readme).to include("3.34.3", "https://registry.npmjs.org/cytoscape/-/cytoscape-3.34.3.tgz",
      Digest::SHA256.file(File.join(vendor, "cytoscape.min.js")).hexdigest)
  end

  it "keeps the vendored fcose layout and its dependencies pinned, licensed and documented" do
    {
      "fcose/cytoscape-fcose.js" => ["2.2.0", "cytoscape-fcose-2.2.0.tgz"],
      "cose-base/cose-base.js" => ["2.2.0", "cose-base-2.2.0.tgz"],
      "layout-base/layout-base.js" => ["2.0.1", "layout-base-2.0.1.tgz"]
    }.each do |file, (version, tarball)|
      dir = File.join(vendor, "..", File.dirname(file))
      readme = File.read(File.join(dir, "README.md"))
      expect(File.read(File.join(dir, "LICENSE"))).to include("Permission is hereby granted, free of charge")
      expect(readme).to include(version, "https://registry.npmjs.org/", tarball, Digest::SHA256.file(File.join(vendor, "..", file)).hexdigest)
    end
  end

  describe "in a headless browser" do
    let(:script) { File.expand_path("support/browser_check.py", __dir__) }

    def browser_report(path)
      out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "python", script, path)
      raise "browser check failed: #{err}" unless status.success?
      JSON.parse(out.lines.last)
    end

    before { skip "uv is not installed" unless system("which uv > /dev/null 2>&1") }

    it "opens from file:// with no network requests, shows the model and treats hostile names as text" do
      render
      r = browser_report(File.expand_path("report.html"))
      expect(r["requests"]).to eq(["file://" + File.expand_path("report.html")])
      expect(r["errors"]).to be_empty
      expect(r["console"].grep(/Content Security Policy|Refused to/)).to be_empty
      expect(r["dialogs"]).to be_empty
      expect(r["pwned"]).to be_nil
      expect(r["injected"]).to eq(0)
      expect(r["hostile_details"]).to include(hostile)
      expect(r["details_children_html"]).not_to include("<img")

      kinds = r["nodes"].group_by { |n| n["kind"] }
      expect(kinds["region"].map { |n| n["id"] }).to contain_exactly("region:eu-west-1", "region:us-east-1")
      expect(kinds["vpc"].map { |n| n["parent"] }).to contain_exactly("region:eu-west-1", "region:us-east-1")
      expect(r["nodes"].find { |n| n["id"] == "sg-web" }["parent"]).to eq("vpc:eu-west-1|vpc-1")
      expect(r["nodes"].find { |n| n["id"] == "0.0.0.0/0" }["parent"]).to be_nil
      expect(r["nodes"].find { |n| n["id"] == "sg-db" }["unused"]).to be(true)
      expect(r["layout"]).to eq("fcose")
      expect(r["overlaps"]).to be_empty
      expect(r["risky_edges"]).to eq(["0.0.0.0/0-sg-web"])

      expect(r["node_details"]).to include("web", "vpc-1", "eu-west-1", "5432")
      expect(r["edge_details"]).to include("Rule descriptions", "5432: app -> ")
      expect(r["dimmed_after_focus"]).to be > 0
      expect(r["ingress_hidden"]).to be(true)
      expect(r["egress_visible"]).to be(true)
      expect(r["matches"]).to eq(["sg-evil"])
    end

    it "opens small graphs fully expanded" do
      render
      r = browser_report(File.expand_path("report.html"))
      expect(r["collapsed"]).to be_empty
      expect(r["nodes"].count { |n| n["kind"] == "group" }).to be < r["threshold"]
    end

    describe "a graph over the collapse threshold" do
      let(:vpcs) { 12 }
      let(:per_vpc) { 15 }

      def render_large(file = "large.html")
        renderer = described_class.new(file, config)
        vpcs.times do |v|
          per_vpc.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "app-#{v}-#{i}", vpc_id: "vpc-#{v}", region: "eu-west-1"}) }
          renderer.add_edge("sg-#{v}-0", "sg-#{v}-1", {color: :blue, label: "443"})
          renderer.add_edge("sg-#{v}-1", "sg-#{(v + 1) % vpcs}-0", {color: :blue, label: "5432"})
          renderer.add_edge("sg-#{v}-2", "sg-#{(v + 1) % vpcs}-3", {color: :blue, label: "22"})
        end
        renderer.add_node("0.0.0.0/0", {label: "0.0.0.0/0"})
        renderer.add_edge("0.0.0.0/0", "sg-0-0", {color: :blue, label: "22", risky: true})
        renderer.output
        file
      end

      def collapse_report(file)
        out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "python",
          File.expand_path("support/browser_collapse.py", __dir__), File.expand_path(file), "vpc:eu-west-1|vpc-3", "app-3-7")
        raise "browser check failed: #{err}" unless status.success?
        JSON.parse(out.lines.last)
      end

      it "starts with every VPC collapsed and expands, collapses and searches on demand" do
        r = collapse_report(render_large)
        expect(vpcs * per_vpc + 1).to be > r["threshold"]
        expect(r["requests"]).to eq(["file://" + File.expand_path("large.html")])
        expect(r["errors"]).to be_empty
        expect(r["console"].grep(/Content Security Policy|Refused to/)).to be_empty
        expect(r["dialogs"]).to be_empty

        expect(r["initial"]).to include("groups" => 1, "vpcs" => vpcs)
        expect(r["initial"]["collapsed"].size).to eq(vpcs)
        expect(r["initial"]["labels"]).to include("vpc-3 (15 groups)")
        expect(r["initial"]["meta"]).to eq(vpcs + 1)
        expect(r["meta_edge_label"]).to match(/\A\d+ rules?\z/)
        expect(r["meta_risky"]).to eq(1)
        expect(r["overlaps"]).to be_empty
        expect(r["collapsed_details"]).to include("vpc-3", "Groups: 15", "Collapsed")
        expect(r["meta_details"]).to include("Merged rules")

        expect(r["after_expand"]["collapsed"].size).to eq(vpcs - 1)
        expect(r["after_expand"]["groups"]).to eq(per_vpc + 1)
        expect(r["expanded_children"]).to eq(per_vpc)
        expect(r["others_moved"]).to be_empty
        expect(r["expanded_details"]).to include("Double-click to collapse")
        expect(r["group_details"]).to include("Id: sg-3-")
        expect(r["after_recollapse"]["collapsed"].size).to eq(vpcs)
        expect(r["ingress_hidden"]).to be(true)

        expect(r["search_matches"]).to eq(["sg-3-7"])
        expect(r["search_vpc_collapsed"]).to be(false)

        expect(r["all_expanded"]).to include("collapsed" => [], "meta" => 0)
        expect(r["all_expanded"]["groups"]).to eq(vpcs * per_vpc + 1)
        expect(r["expanded_overlaps"]).to be_empty
        expect(r["all_collapsed"]["collapsed"].size).to eq(vpcs)
      end
    end
  end
end
