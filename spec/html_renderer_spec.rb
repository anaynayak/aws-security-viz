# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"
require "digest"
require "open3"

describe AwsSecurityViz::Renderer::Html do
  let(:hostile) { %(<img src=x onerror="window.pwned=1"></script><script>window.pwned=2</script>) }
  let(:hostile_name) { %(<img src=x onerror="window.pwned=1"><b>evil</b>) }
  let(:config) { AwsSecurityViz::AwsConfig.new({}) }
  let(:vendor) { File.expand_path("../lib/aws_security_viz/vendor/cytoscape", __dir__) }

  let(:layout_files) { %w[layout-base/layout-base.js cose-base/cose-base.js fcose/cytoscape-fcose.js dagre/dagre.min.js cytoscape-dagre/cytoscape-dagre.js] }

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
    layout_files.each { |file| expect(html).to include(File.read(File.join(vendor, "..", file))) }
    expect(html).not_to match(/<script[^>]*\ssrc=/i)
    expect(html).not_to match(/<link[^>]*href=/i)
    expect(html).not_to include("/*DATA*/", "/*CYTOSCAPE*/", "/*DAGRE*/", "/*CYTOSCAPE_DAGRE*/")
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

  it "has the browser check return null from tap, because Playwright cannot serialise a Cytoscape collection" do
    source = File.read(File.expand_path("support/browser_check.py", __dir__))
    expect(source).to include("emit('tap'); return null")
  end

  it "keeps the vendored layouts (fcose, dagre) and their dependencies pinned, licensed and documented" do
    {
      "fcose/cytoscape-fcose.js" => ["2.2.0", "cytoscape-fcose-2.2.0.tgz"],
      "cose-base/cose-base.js" => ["2.2.0", "cose-base-2.2.0.tgz"],
      "layout-base/layout-base.js" => ["2.0.1", "layout-base-2.0.1.tgz"],
      "dagre/dagre.min.js" => ["0.8.5", "dagre-0.8.5.tgz"],
      "cytoscape-dagre/cytoscape-dagre.js" => ["2.5.0", "cytoscape-dagre-2.5.0.tgz"]
    }.each do |file, (version, tarball)|
      dir = File.join(vendor, "..", File.dirname(file))
      readme = File.read(File.join(dir, "README.md"))
      expect(File.read(File.join(dir, "LICENSE"))).to include("Permission is hereby granted, free of charge")
      expect(File.read(File.join(dir, "LICENSE"))).to include("OpenJS Foundation") if file.start_with?("dagre/") # dagre.min.js bundles lodash
      expect(readme).to include("lodash") if file.start_with?("dagre/")
      expect(readme).to include(version, "https://registry.npmjs.org/", tarball, Digest::SHA256.file(File.join(vendor, "..", file)).hexdigest)
    end
  end

  describe "the page design" do
    let(:page) { render }
    let(:style) { page[%r{<style>.*?</style>}m] }

    it "takes its colours, spacing and type from CSS custom properties and uses the system font stack" do
      expect(style).to include("--bg:", "--text:", "--accent:", "--space-2:", "--font: system-ui")
      expect(style).not_to match(/@font-face|@import|url\(/)
    end

    it "has a light theme, a dark theme for prefers-color-scheme, and a manual toggle that sets data-theme" do
      expect(style).to include("@media (prefers-color-scheme: dark)", ':root[data-theme="dark"]', ':root:not([data-theme="light"])')
      expect(page).to match(/<button id="theme"[^>]*aria-pressed/)
    end

    it "shows a legend that names every node and edge kind with a shape or width, not only a colour" do
      legend = page[%r{<details id="legend".*?</details>}m]
      expect(legend).to include("Security group", "CIDR (cut corners)", "IPv6 CIDR (double outline)", "Prefix list (tag)", "Unused group", "Collapsed VPC",
        "Takes risky ingress", "Ingress (thick, filled arrow)", "Egress (thin, open arrow)", "public ingress (thickest)", "Path result")
      expect(legend.scan("<svg").size).to be >= 11
    end

    it "marks exposed groups with a class and not with an id selector" do
      expect(page).to include('"node.exposed"')
      expect(page).not_to include("node[id = ")
    end
  end

  describe "in a headless browser" do
    let(:script) { File.expand_path("support/browser_check.py", __dir__) }

    def browser_report(path)
      JSON.parse(run_browser_script(script, path).lines.last)
    end

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
      expect(r["risky_only_group_details"]).to include("0.0.0.0/0")
      expect(r["risky_only_group_details"]).not_to include("5432", "db :")
      expect(r["vpc_label_collapsed"]).to eq("vpc-1 (2 groups)")
      expect(r["vpc_label_expanded"]).to eq("vpc-1")
    end

    it "opens small graphs fully expanded" do
      render
      r = browser_report(File.expand_path("report.html"))
      expect(r["collapsed"]).to be_empty
      expect(r["nodes"].count { |n| n["kind"] == "group" }).to be < r["threshold"]
    end

    it "counts security groups, not peers, against the collapse threshold" do
      renderer = described_class.new("peers.html", config)
      10.times { |v| 15.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "g", vpc_id: "vpc-#{v}", region: "eu-west-1"}) } }
      20.times { |i| renderer.add_node("10.0.#{i}.0/24", {label: "10.0.#{i}.0/24"}) }
      renderer.output
      out = run_browser_script(File.expand_path("support/browser_state.py", __dir__), File.expand_path("peers.html"))
      r = JSON.parse(out.lines.last)
      expect(r["threshold"]).to eq(150)
      expect(r["collapsed"]).to eq(0)
    end

    describe "drawing" do
      def visible_report(file, vpc)
        out = run_browser_script(File.expand_path("support/browser_visible.py", __dir__), File.expand_path(file), vpc)
        JSON.parse(out.lines.last)
      end

      def expect_everything_drawn(r)
        expect(r["errors"]).to be_empty
        expect(r["console"].grep(/Content Security Policy|Refused to/)).to be_empty
        expect(r["steps"].keys).to include("load", "expand_all", "collapse_all", "dblclick_1", "dblclick_2", "webgl_on", "webgl_dblclick", "webgl_off")
        r["steps"].each do |name, s|
          expect(s["invisible"]).to be_empty, "#{name}: invisible #{s["invisible"].first(3)}"
          expect(s["zeroEdges"]).to be_empty, "#{name}: edges without a box #{s["zeroEdges"].first(3)}"
          expect(s["vpcOverlaps"]).to be_empty, "#{name}: VPCs overlap #{s["vpcOverlaps"].first(3)}"
          expect(s["groupOverlaps"]).to be_empty, "#{name}: groups overlap #{s["groupOverlaps"].first(3)}"
          expect(s["peerInVpc"]).to be_empty, "#{name}: peers inside a VPC #{s["peerInVpc"].first(3)}"
          expect(s["ink"]).to be > 8, "#{name}: no edge pixels on screen (#{s["ink"]})"
        end
        expect(r["steps"]["webgl_on"]["renderer"]).to eq("webgl")
        expect(r["steps"]["webgl_off"]["renderer"]).to eq("canvas")
        r.select { |k, _| k.start_with?("toggled_") }.each_value { |(was, now)| expect(now).to eq(!was) }
        expect(r["children_dblclick_collapsed"] || 0).to eq(0)
      end

      it "draws every node and edge, without overlaps, after load, expand, collapse, double-click and renderer switches (small)" do
        renderer = described_class.new("drawn.html", config)
        2.times do |v|
          8.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "svc-#{v}-#{i}", vpc_id: "vpc-#{v}", region: "eu-west-1"}) }
          7.times { |i| renderer.add_edge("sg-#{v}-#{i}", "sg-#{v}-#{i + 1}", {color: :blue, label: "443"}) }
          renderer.add_edge("sg-#{v}-0", "sg-#{1 - v}-3", {color: :red, label: "all"})
        end
        renderer.add_node("0.0.0.0/0", {label: "0.0.0.0/0"})
        renderer.add_node("10.0.0.0/8", {label: "10.0.0.0/8"})
        renderer.add_edge("0.0.0.0/0", "sg-0-0", {color: :blue, label: "22", risky: true})
        renderer.add_edge("10.0.0.0/8", "sg-1-2", {color: :blue, label: "22"})
        renderer.output
        r = visible_report("drawn.html", "vpc:eu-west-1|vpc-1")
        expect_everything_drawn(r)
      end

      it "draws every node and edge, without overlaps, on a graph that opens collapsed (large)" do
        renderer = described_class.new("drawn-large.html", config)
        12.times do |v|
          15.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "app-#{v}-#{i}", vpc_id: "vpc-#{v}", region: "eu-west-1"}) }
          15.times { |i| renderer.add_edge("sg-#{v}-#{i}", "sg-#{v}-#{(i + 1) % 15}", {color: :blue, label: "443"}) }
          renderer.add_edge("sg-#{v}-1", "sg-#{(v + 1) % 12}-0", {color: :red, label: "5432"})
          renderer.add_edge("sg-#{v}-2", "sg-#{(v + 5) % 12}-3", {color: :blue, label: "22"})
        end
        %w[0.0.0.0/0 10.0.0.0/8 ::/0].each { |peer| renderer.add_node(peer, {label: peer}) }
        12.times { |v| renderer.add_edge("0.0.0.0/0", "sg-#{v}-4", {color: :blue, label: "22", risky: v.zero?}) }
        renderer.add_edge("10.0.0.0/8", "sg-3-3", {color: :blue, label: "22"})
        renderer.output
        r = visible_report("drawn-large.html", "vpc:eu-west-1|vpc-3")
        expect(r["steps"]["load"]["nodes"]).to be < 30
        expect_everything_drawn(r)
        expect(r["toggled_dblclick_1"]).to eq([true, false])
        expect(r["toggled_dblclick_2"]).to eq([false, true])
        expect(r["children_dblclick_2"]).to eq(0)
      end

      it "makes risky edges look different from merged egress edges and says so in the legend" do
        render
        out = run_browser_script(File.expand_path("support/browser_style.py", __dir__), File.expand_path("report.html"), "web")
        r = JSON.parse(out.lines.last)
        expect(r["errors"]).to be_empty
        risky = r["styles"]["risky"]
        [r["styles"]["mergedEgress"], r["styles"]["mergedIngress"], r["styles"]["egress"]].each do |other|
          expect(risky["width"]).to be > other["width"]
          expect(risky["color"]).not_to eq(other["color"])
        end
        expect(risky["arrowScale"]).to be > 1
        expect(r["legend"]).to match(/risky public ingress/i)
        expect(r["legend"]).not_to include("thick dashed")
      end

      def followup_report(file, vpc)
        out = run_browser_script(File.expand_path("support/browser_followup.py", __dir__), File.expand_path(file), vpc)
        JSON.parse(out.lines.last)
      end

      def render_vpcs(file, vpcs:, per_vpc:)
        renderer = described_class.new(file, config)
        vpcs.times do |v|
          per_vpc.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "service-group-#{v}-#{i}", vpc_id: "vpc-#{v}", region: "eu-west-1"}) }
          per_vpc.times { |i| renderer.add_edge("sg-#{v}-#{i}", "sg-#{v}-#{(i * 7 + 3) % per_vpc}", {color: :blue, label: "443"}) }
          renderer.add_edge("sg-#{v}-1", "sg-#{(v + 1) % vpcs}-0", {color: :red, label: "5432"})
        end
        renderer.add_node("0.0.0.0/0", {label: "0.0.0.0/0"})
        vpcs.times { |v| renderer.add_edge("0.0.0.0/0", "sg-#{v}-4", {color: :blue, label: "22"}) }
        renderer.output
        file
      end

      it "says the right thing in the details panel after a VPC is expanded or collapsed" do
        render_vpcs("follow.html", vpcs: 12, per_vpc: 15)
        r = followup_report("follow.html", "vpc:eu-west-1|vpc-3")
        expect(r["errors"]).to be_empty
        expect(r["details_collapsed"]).to include("Collapsed: double-click to expand")
        expect(r["details_expanded"]).to include("Double-click to collapse")
        expect(r["details_expanded"]).not_to include("Collapsed")
        expect(r["details_recollapsed"]).to include("Collapsed: double-click to expand")
      end

      it "brings an expanded VPC into view when it would run off the screen" do
        render_vpcs("follow-big.html", vpcs: 8, per_vpc: 40)
        r = followup_report("follow-big.html", "vpc:eu-west-1|vpc-3")
        expect(r["expanded_in_view"]).to be(true)
        expect(r["zoom_after"]).to be <= r["zoom_before"]
      end

      it "sizes nodes for the font their labels are drawn in, and fits the graph again when the window is resized" do
        render_vpcs("follow-size.html", vpcs: 12, per_vpc: 15)
        r = followup_report("follow-size.html", "vpc:eu-west-1|vpc-3")
        expect(r["label_fit"]).to be_empty
        expect(r["fits_after_resize"]).to be(true)
      end

      it "leaves no groups overlapping inside a dense VPC after Expand all" do
        renderer = described_class.new("dense.html", config)
        rng = Random.new(7)
        3.times do |v|
          70.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "svc-#{v}-#{i}", vpc_id: "vpc-#{v}", region: "eu-west-1"}) }
          70.times { |i| 9.times { renderer.add_edge("sg-#{v}-#{i}", "sg-#{v}-#{rng.rand(70)}", {color: :blue, label: (1000 + rng.rand(40)).to_s}) } }
        end
        renderer.output
        r = visible_report("dense.html", "vpc:eu-west-1|vpc-1")
        expect(r["steps"]["expand_all"]["groupOverlaps"]).to be_empty
        expect(r["steps"]["expand_all"]["vpcOverlaps"]).to be_empty
      end

      it "keeps a single search match at a readable zoom" do
        render
        out = run_browser_script(File.expand_path("support/browser_style.py", __dir__), File.expand_path("report.html"), "sg-db")
        r = JSON.parse(out.lines.last)
        expect(r["search_matches"]).to eq(1)
        expect(r["search_zoom"]).to be <= 1.5
        expect(r["search_match_in_view"]).to be(true)
      end
    end

    describe "the layout picker" do
      let(:layouts) { %w[fcose flow rings grid] }

      def small_shape(file = "layouts-small.html")
        renderer = described_class.new(file, config)
        2.times do |v|
          8.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "svc-#{v}-#{i}", vpc_id: "vpc-#{v}", region: "eu-west-1"}) }
          7.times { |i| renderer.add_edge("sg-#{v}-#{i}", "sg-#{v}-#{i + 1}", {color: :blue, label: "443"}) }
          renderer.add_edge("sg-#{v}-0", "sg-#{1 - v}-3", {color: :red, label: "all"})
        end
        renderer.add_node("0.0.0.0/0", {label: "0.0.0.0/0"})
        renderer.add_node("10.0.0.0/8", {label: "10.0.0.0/8"})
        renderer.add_edge("0.0.0.0/0", "sg-0-0", {color: :blue, label: "22", risky: true})
        renderer.add_edge("10.0.0.0/8", "sg-1-2", {color: :blue, label: "22"})
        renderer.output
        file
      end

      # Twelve VPCs of fifteen groups: opens collapsed.
      def large_shape(file = "layouts-large.html")
        renderer = described_class.new(file, config)
        12.times do |v|
          15.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "app-#{v}-#{i}", vpc_id: "vpc-#{v}", region: "eu-west-1"}) }
          15.times { |i| renderer.add_edge("sg-#{v}-#{i}", "sg-#{v}-#{(i + 1) % 15}", {color: :blue, label: "443"}) }
          renderer.add_edge("sg-#{v}-1", "sg-#{(v + 1) % 12}-0", {color: :red, label: "5432"})
          renderer.add_edge("sg-#{v}-2", "sg-#{(v + 5) % 12}-3", {color: :blue, label: "22"})
        end
        %w[0.0.0.0/0 10.0.0.0/8 ::/0].each { |peer| renderer.add_node(peer, {label: peer}) }
        12.times { |v| renderer.add_edge("0.0.0.0/0", "sg-#{v}-4", {color: :blue, label: "22", risky: v.zero?}) }
        renderer.add_edge("10.0.0.0/8", "sg-3-3", {color: :blue, label: "22"})
        renderer.output
        file
      end

      def layout_report(file, vpc)
        out = run_browser_script(File.expand_path("support/browser_layouts.py", __dir__), File.expand_path(file), vpc)
        JSON.parse(out.lines.last).tap do |r|
          expect(r["picker"]).to be(true), "the viewer has no #layout picker"
          expect(r["options"]).to eq(layouts)
        end
      end

      it "gives an opened VPC's panel a working Collapse button in every layout and the double-click hint only where it works" do
        file = small_shape
        out = run_browser_script(File.expand_path("support/browser_vpc_panel.py", __dir__), File.expand_path(file), "vpc:eu-west-1|vpc-0")
        r = JSON.parse(out.lines.last)
        expect(r["errors"]).to be_empty
        layouts.each do |l|
          step = r["layouts"][l]
          expect(step["buttons"]).to eq(["Collapse vpc-0"]), "#{l}: the VPC panel offers #{step["buttons"]}"
          expect(step["collapsed_after"]).to be(true), "#{l}: the Collapse button did not collapse the VPC"
          if l == "rings"
            expect(step["details"]).not_to include("Double-click to collapse"), "rings: the panel promises a double-click that cannot work"
          else
            expect(step["details"]).to include("Double-click to collapse"), "#{l}: no double-click hint"
          end
        end
      end

      # What every layout owes: all of it drawn, fitted, not overlapping, on screen as pixels, from file:// only.
      def expect_laid_out(r, file)
        expect(r["requests"]).to eq(["file://" + File.expand_path(file)])
        expect(r["errors"]).to be_empty
        expect(r["console"].grep(/Content Security Policy|Refused to/)).to be_empty
        expect(r["steps"].keys).to include(*layouts.flat_map { |l| %W[#{l}:load #{l}:expand_all #{l}:collapse_all #{l}:dblclick_expand #{l}:webgl] })
        r["steps"].each do |name, s|
          layout = name.split(":").first
          expect(s["layout"]).to eq(layout), "#{name}: layout is #{s["layout"]}"
          expect(s["invisible"]).to be_empty, "#{name}: invisible #{s["invisible"].first(3)}"
          expect(s["zeroEdges"]).to be_empty, "#{name}: edges without a box #{s["zeroEdges"].first(3)}"
          expect(s["notFinite"]).to be_empty, "#{name}: nodes without a position or size #{s["notFinite"].first(3)}"
          expect(s["overlaps"]).to be_empty, "#{name}: nodes overlap #{s["overlaps"].first(3)}"
          expect(s["overlapsAll"]).to be_empty, "#{name}: nodes overlap across VPCs #{s["overlapsAll"].first(3)}"
          if s["flat"]
            boxes = s["flatBoxes"]
            expect(boxes["selected"]).to eq(0), "#{name}: a VPC box is selected"
            expect([boxes["labels"], boxes["overlay"], boxes["fill"], boxes["border"]]).to all(be_empty), "#{name}: VPC boxes draw something: #{boxes}"
          end
          expect(s["vpcOverlaps"]).to be_empty, "#{name}: VPCs overlap #{s["vpcOverlaps"].first(3)}" unless s["flat"]
          expect(s["flat"]).to be(layout == "rings"), "#{name}: VPC boxes drawn: #{!s["flat"]}"
          expect(s["ink"]).to be > 0, "#{name}: no edge pixels on screen"
          # Two hundred nodes fitted on one screen are a few pixels each, too small to tell from their outline.
          expect(s["nodeInk"]).to be > 0, "#{name}: no node pixels on screen" if s["nodes"] < 100
          # The force layout keeps the view where it was when one VPC opens or closes; the others fit everything again.
          expect(s["outside"]).to be_empty, "#{name}: not fitted, outside the view: #{s["outside"].first(3)}" unless layout == "fcose" && name.match?(/dblclick/)
        end
        expect(r["repick_moved"]).to be < 1, "picking fcose again moved nodes by #{r["repick_moved"]} px"
        layouts.each do |l|
          expect(r["button"][l]["text"]).to start_with("Collapse"), "#{l}: no Collapse button in a group's panel"
          expect(r["button"][l]["collapsed"]).to be(true), "#{l}: the Collapse button did not collapse the VPC"
        end
        expect(r["steps"].select { |k, _| k.end_with?(":webgl") }.values.map { |s| s["renderer"] }.uniq).to eq(["webgl"])
        expect(r["steps"].select { |k, _| k.end_with?(":load") }.values.map { |s| s["renderer"] }.uniq).to eq(["canvas"])
        expect(r["steps"].select { |k, _| k.end_with?(":dblclick_expand") }.values.map { |s| s["children"] }).to all(be > 0)
      end

      def steps_of(r, layout, *names)
        names.map { |n| r["steps"]["#{layout}:#{n}"] }
      end

      [["small", :small_shape, "vpc:eu-west-1|vpc-1"], ["large", :large_shape, "vpc:eu-west-1|vpc-3"]].each do |shape, builder, vpc|
        it "lays out the #{shape} demo shape with every layout, drawn and fitted, with external peers in a column or in the centre" do
          file = send(builder)
          r = layout_report(file, vpc)
          expect_laid_out(r, file)
          expanded = %w[load expand_all webgl]
          # Force layout: sources of rules lie left of their targets for the first tiers; peers share one column.
          steps_of(r, "fcose", *expanded).each do |s|
            expect(s["tierColumns"]).to be_empty, "tiers do not run left to right: #{s["tierColumns"].first(3)}"
            expect(s["peerSpread"]).to be < 1
          end
          # Grid: a row per tier inside each VPC, peers in a column left of the grid.
          layouts.each { |l| expect(steps_of(r, l, "load").first["peers"]).to be > 0 }
          steps_of(r, "grid", *%w[load expand_all collapse_all dblclick_expand dblclick_collapse webgl]).each do |s|
            expect(s["tierRows"]).to be_empty, "tiers do not run top to bottom: #{s["tierRows"].first(3)}"
            expect(s["peerSpread"]).to be < 1
            expect(s["peerLeft"]).to be(true)
          end
          # Flow with VPCs open uses the width of the view, not a narrow strip.
          steps_of(r, "flow", "load", "expand_all").each { |s| expect(s["usedWidth"]).to be > 0.6, "flow uses #{(s["usedWidth"] * 100).round}% of the width" }
          # Flow: peers in their own column on the left.
          steps_of(r, "flow", *%w[load expand_all collapse_all dblclick_expand dblclick_collapse webgl]).each do |s|
            expect(s["peerSpread"]).to be < 1
            expect(s["peerLeft"]).to be(true)
          end
          # Rings: distance from the centre never decreases with the hop count.
          steps_of(r, "rings", *%w[load expand_all collapse_all dblclick_expand webgl]).each do |s|
            expect(s["ringBad"]).to be_empty, "rings out of order: #{s["ringBad"].first(3)}"
            expect(s["publicRadius"]).to all(be < 80), "the public peers are not at the centre: #{s["publicRadius"]}"
          end
          # Flow runs along the rule direction when the rules have no cycle (the small shape).
          if shape == "small"
            steps_of(r, "flow", *expanded).each { |s| expect(s["flowBack"]).to be_empty, "rules run right to left: #{s["flowBack"].first(3)}" }
            steps_of(r, "rings", "load").each { |s| expect(s["publicRadius"].first).to be < 1 }
          end
        end
      end

      it "hides labels when zoomed out, shows an edge's port label on hover and while selected, and fades what a selection leaves out" do
        file = small_shape
        out = run_browser_script(File.expand_path("support/browser_readability.py", __dir__), File.expand_path(file))
        r = JSON.parse(out.lines.last)
        expect(r["errors"]).to be_empty
        expect(r["grey_in"]).to be > 500
        expect(r["zoom_out"]).to be < 0.3
        expect(r["grey_out"]).to be < 150, "label text still drawn when zoomed out (#{r["grey_out"]} grey pixels, #{r["grey_in"]} when fitted)"
        expect(r["label_before_hover"]).to eq(0), "an edge label is drawn without hover or selection"
        expect(r["hovered"]).to eq([r["spot"]["id"]])
        expect(r["label_on_hover"]).to be > 5
        expect(r["selected"]).to eq([r["spot"]["id"]])
        expect(r["label_selected"]).to be > 5
        expect(r["faded"]["count"]).to be > 0
        expect(r["faded"]["count"]).to be < r["faded"]["total"]
        expect(r["faded"]["opacities"]).to all(be_between(0.05, 0.5))
        expect(r["faded"]["shown"]).to be(true)
        expect(r["neighbour_labels"]).to be > 0
        # Labels the user asked for show at any zoom.
        expect(r["out_label_before_hover"]).to eq(0)
        # A label is only a couple of pixels high at this zoom, too few to tell from the edge's own anti-aliased pixels on every
        # platform, and edges overlap so the pointer may pick a neighbour of the edge aimed at. So the check is the style the hover
        # gives the edge it picked: its port label shown, with no minimum zoomed size (the pixels are checked at a readable zoom above).
        hovered = r["out_hover_label"]
        expect(hovered).not_to be_nil, "no edge is hovered at zoom #{r["zoom_out"]}"
        expect(hovered["label"]).to eq(hovered["data"])
        expect(hovered["label"]).not_to be_empty
        expect(hovered["minZoomed"]).to eq(0)
        expect(hovered["opacity"]).to be > 0
        expect(r["out_selected"]).not_to be_empty
        expect(r["grey_out_selected"]).to be > 20, "a selected node and its neighbours have no labels at zoom #{r["zoom_out_selected"]}"
      end
    end

    describe "the light and dark themes" do
      def theme_report
        file = "theme.html"
        renderer = described_class.new(file, config)
        2.times do |v|
          8.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "svc-#{v}-#{i}", vpc_id: "vpc-#{v}", region: "eu-west-1"}) }
          7.times { |i| renderer.add_edge("sg-#{v}-#{i}", "sg-#{v}-#{i + 1}", {color: :blue, label: "443"}) }
          renderer.add_edge("sg-#{v}-0", "sg-#{1 - v}-3", {color: :red, label: "all"})
        end
        %w[0.0.0.0/0 10.0.0.0/8].each { |peer| renderer.add_node(peer, {label: peer}) }
        renderer.add_edge("0.0.0.0/0", "sg-0-0", {color: :blue, label: "22", risky: true})
        renderer.add_edge("10.0.0.0/8", "sg-1-2", {color: :blue, label: "22"})
        renderer.output
        JSON.parse(run_browser_script(File.expand_path("support/browser_theme.py", __dir__), File.expand_path(file)).lines.last)
      end

      it "follows prefers-color-scheme, switches with the toggle, and restyles in place on canvas and WebGL" do
        r = theme_report
        expect(r["toggle"]).to be(true), "the viewer has no #theme toggle"
        expect(r["errors"]).to be_empty
        expect(r["requests"].uniq).to eq(["file://" + File.expand_path("theme.html")])
        expect(r["follows_browser"]).to eq("dark")
        expect(r["keeps_choice"]).to eq("light")
        expect(r["runs"].keys).to eq(%w[light-canvas light-webgl dark-canvas dark-webgl])
        r["runs"].each do |name, run|
          start = name.split("-").first
          other = (start == "light") ? "dark" : "light"
          expect(run["theme"]).to eq(start), "#{name}: opened in #{run["theme"]}"
          expect(run["renderer"]).to eq(name.split("-").last)
          expect(run["switched_to"]).to eq(other)
          expect(run["data_theme"]).to eq(other)
          expect(run["pressed_after"]).to eq((other == "dark") ? "true" : "false")
          expect(run["corner_before"]).not_to eq(run["corner_after"]), "#{name}: the canvas background did not change"
          expect(run["round_trip"]).to be(true), "#{name}: switching back did not restore the first look"
          expect(run["probe_mismatch_before"]).to be_empty, "#{name}: #{run["probe_mismatch_before"]}"
          expect(run["probe_mismatch_after"]).to be_empty, "#{name}: after the switch: #{run["probe_mismatch_after"]}"
          # Nothing is laid out again or lost: positions, view, selection, collapse state, search and filters stay.
          expect(run["max_moved"]).to eq(0), "#{name}: nodes moved by #{run["max_moved"]}"
          expect(run["state_kept"].reject { |_, kept| kept }.keys).to be_empty, "#{name}: lost #{run["state_kept"].reject { |_, kept| kept }.keys}"
          expect(run["selection"]).to eq(["sg-0-2"])
          expect(run["legend_overlap"].values.flatten).to be_empty, "#{name}: the legend covers #{run["legend_overlap"]}"
        end
        expect(r["runs"]["light-canvas"]["corner_before"]).to eq([246, 248, 251])
        expect(r["runs"]["dark-webgl"]["corner_before"]).to eq([15, 23, 32])
      end

      it "keeps graph colours at WCAG AA against the canvas and chrome text readable in both themes" do
        r = theme_report
        expect(r["toggle"]).to be(true)
        r["runs"].each do |name, run|
          %w[graph_contrast chrome_contrast graph_contrast_after chrome_contrast_after].each do |key|
            expect(run[key]).to be_empty, "#{name} #{key}: #{run[key]}"
          end
        end
      end
    end

    describe "peer kinds" do
      it "keeps the shapes of CIDRs and the internet in an obfuscated report, where the ids are hashes" do
        file = File.expand_path("obfuscated.html")
        config = AwsSecurityViz::AwsConfig.new(obfuscate: true)
        source = File.expand_path("integration/dummy.json", __dir__)
        AwsSecurityViz::VisualizeAws.new(config, source_file: source, renderer: "html").unleash(file)
        expect(File.read(file)[%r{id="graph-data">(.*?)</script>}m, 1]).not_to include("0.0.0.0/0")
        out = run_browser_script(File.expand_path("support/browser_peers.py", __dir__), file)
        r = JSON.parse(out.lines.last)
        expect(r["errors"]).to be_empty
        expect(r["classes"].count { |c| c.include?("cidr") }).to be >= 2
        expect(r["classes"].count { |c| c.include?("internet") }).to eq(1)
      end
    end

    describe "exposed VPCs" do
      it "draws a VPC as exposed only while it is collapsed, whichever way it got that way" do
        file = "exposed.html"
        renderer = described_class.new(file, config)
        2.times { |v| 3.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "svc-#{v}-#{i}", vpc_id: "vpc-#{v}", region: "eu-west-1"}) } }
        renderer.add_node("0.0.0.0/0", {label: "0.0.0.0/0"})
        renderer.add_edge("0.0.0.0/0", "sg-0-0", {color: :blue, label: "22", risky: true})
        renderer.add_edge("sg-1-0", "sg-1-1", {color: :blue, label: "443"})
        renderer.output
        out = run_browser_script(File.expand_path("support/browser_exposed.py", __dir__), File.expand_path(file), "vpc:eu-west-1|vpc-0")
        r = JSON.parse(out.lines.last)
        expect(r["errors"]).to be_empty
        expect(r["open"]).to eq({"collapsed" => false, "exposed" => false})
        expect(r["collapse_all"]).to eq({"collapsed" => true, "exposed" => true})
        expect(r["expand_all"]).to eq({"collapsed" => false, "exposed" => false})
        expect(r["dblclick"]).to eq({"collapsed" => true, "exposed" => true})
      end
    end

    describe "the WebGL renderer" do
      def webgl_report(file, *flags)
        out = run_browser_script(File.expand_path("support/browser_webgl.py", __dir__), File.expand_path(file), *flags)
        JSON.parse(out.lines.last)
      end

      def expect_clean(r, file)
        expect(r["requests"]).to eq(["file://" + File.expand_path(file)])
        expect(r["errors"]).to be_empty
        expect(r["console"].grep(/Content Security Policy|Refused to/)).to be_empty
        expect(r["dialogs"]).to be_empty
      end

      # One VPC of 160 groups starts collapsed (a single node) and has about 2,200 elements once expanded.
      def render_dense(file = "dense.html")
        renderer = described_class.new(file, config)
        160.times { |i| renderer.add_node("sg-#{i}", {label: "g#{i}", vpc_id: "vpc-1", region: "eu-west-1"}) }
        160.times { |i| 13.times { |k| renderer.add_edge("sg-#{i}", "sg-#{(i + k + 1) % 160}", {color: k.odd? ? :red : :blue, label: (1000 + k).to_s}) } }
        renderer.output
        file
      end

      it "starts on canvas for a small graph and the checkbox switches renderer without losing the view" do
        render
        r = webgl_report("report.html")
        expect_clean(r, "report.html")
        expect(r["initial"]).to include("renderer" => "canvas", "checked" => false, "disabled" => false)
        expect(r["toggled_on"]).to include("renderer" => "webgl", "checked" => true, "elements" => r["initial"]["elements"])
        expect(r["pre_toggle"]["positions"].size).to eq(r["toggled_on"]["nodes"])
        expect(r["post_toggle"]["positions"]).to eq(r["pre_toggle"]["positions"])
        expect(r["post_toggle"]["zoom"]).to eq(r["pre_toggle"]["zoom"])
        expect(r["post_toggle"]["pan"]).to eq(r["pre_toggle"]["pan"])
        expect(r["details_after_switch"]).to include("Id: sg-")
        expect(r["ingress_hidden"]).to be(true)
        expect(r["toggled_off"]).to include("renderer" => "canvas", "checked" => false)
      end

      it "falls back to canvas without errors when the browser has no WebGL" do
        render
        r = webgl_report("report.html", "--no-webgl")
        expect_clean(r, "report.html")
        expect(r["initial"]).to include("renderer" => "canvas", "checked" => false, "disabled" => true)
        expect(r["final"]).to include("renderer" => "canvas")
      end

      it "turns WebGL on by itself once more than the threshold of elements are on the canvas" do
        render_dense
        r = webgl_report("dense.html", "--expand-all")
        expect_clean(r, "dense.html")
        expect(r["threshold"]).to eq(2000)
        expect(r["initial"]).to include("renderer" => "canvas")
        expect(r["initial"]["elements"]).to be <= r["threshold"]
        expect(r["after_expand_all"]).to include("renderer" => "webgl", "checked" => true)
        expect(r["after_expand_all"]["elements"]).to be > r["threshold"]
        expect(r["toggled_on"]).to include("renderer" => "canvas", "checked" => false)
        expect(r["details_after_switch"]).to include("Id: sg-")
      end

      it "falls back to canvas and clears what a failed WebGL start left behind" do
        render
        r = webgl_report("report.html", "--webgl-throws")
        expect_clean(r, "report.html")
        expect(r["after_throw"]).to include("renderer" => "canvas", "checked" => false, "disabled" => true)
        expect(r["after_throw"]["nodes"]).to be > 0
        expect(r["stray_canvases"]).to eq(r["after_throw"]["canvases"])
      end

      it "carries on with canvas when the browser takes the WebGL context away" do
        render
        r = webgl_report("report.html", "--lose-context")
        expect_clean(r, "report.html")
        expect(r["toggled_on"]).to include("renderer" => "webgl")
        expect(r["after_loss"]).to include("renderer" => "canvas", "checked" => false, "disabled" => true)
        expect(r["after_loss"]["nodes"]).to eq(r["toggled_on"]["nodes"])
      end

      it "releases each WebGL context so repeated switching never reaches the browser limit" do
        render
        r = webgl_report("report.html", "--churn")
        expect_clean(r, "report.html")
        expect(r["console"].grep(/Too many active WebGL contexts/)).to be_empty
        expect(r["after_churn"]).to include("renderer" => "webgl", "checked" => true)
        expect(r["contexts_created"]).to be > 20
        expect(r["contexts_alive"]).to be <= 2
      end

      it "stays on canvas past the threshold when WebGL is missing" do
        render_dense
        r = webgl_report("dense.html", "--expand-all", "--no-webgl")
        expect_clean(r, "dense.html")
        expect(r["after_expand_all"]["elements"]).to be > r["threshold"]
        expect(r["after_expand_all"]).to include("renderer" => "canvas", "disabled" => true)
      end
    end

    describe "the path query" do
      let(:fixture) { File.expand_path("fixtures/path_semantics.json", __dir__) }

      def path_report(file, queries, *flags)
        out = run_browser_script(File.expand_path("support/browser_path.py", __dir__), File.expand_path(file), JSON.generate(queries), *flags)
        JSON.parse(out.lines.last).tap { |r| expect(r["picker"]).to be(true), "the viewer has no #path-from picker" }
      end

      def expect_clean(r, file)
        expect(r["requests"]).to eq(["file://" + File.expand_path(file)])
        expect(r["errors"]).to be_empty
        expect(r["console"].grep(/Content Security Policy|Refused to/)).to be_empty
        expect(r["dialogs"]).to be_empty
      end

      def render_fixture(source: fixture, config: self.config, **opts)
        AwsSecurityViz::VisualizeAws.new(config, {source_file: source, renderer: "html"}.merge(opts)).unleash("report.html")
        "report.html"
      end

      def answers(queries, **render_options)
        path_report(render_fixture(**render_options), queries)["queries"]
      end

      let(:adversarial) { File.expand_path("fixtures/path_adversarial.json", __dir__) }

      it "finds a path, draws it and lists each hop with its egress and ingress rules, ports and descriptions" do
        r = path_report(render_fixture, [{from: "0.0.0.0/0", to: "db"}])
        expect_clean(r, "report.html")
        q = r["queries"].first
        expect(q["pathNodes"]).to eq(%w[0.0.0.0/0 sg-db sg-web])
        expect(q["pathEdges"]).to eq(%w[0.0.0.0/0-sg-web sg-web-sg-db])
        expect(q["details"]).to include("Reachable in 2 hops", "Hop 1: 0.0.0.0/0 -> web", "443/tcp from 0.0.0.0/0",
          "Hop 2: web -> db", "Egress on web", "5432/tcp to db", " - web to db", "Ingress on db", "5432/tcp from web", " - db from web",
          "Allowed ports: 5432/tcp", "not computed", "network ACLs, route tables")
        expect(q["dimmed"]).to be > 0
        expect(q["allVisible"]).to be(true)
        expect(q["orange"]).to be > 200
        expect(r["before"]["orange"]).to eq(0)
        expect(q["cleared"]).to include("dimmed" => 0, "pathEdges" => [], "orange" => 0, "inputs" => ["", "", ""])
        expect(q["cleared"]["zoom"]).to eq(r["before"]["zoom"])
        expect(q["cleared"]["pan"]).to eq(r["before"]["pan"])
      end

      it "needs both sides: egress alone, ingress alone and disagreeing ports are blocked, and the message says which side" do
        q = answers([{from: "c-egress-to-d", to: "d-no-ingress", click: true}, {from: "g-public", to: "r-ingress-from-g"},
          {from: "e-egress-443-to-f", to: "f-ingress-22-from-e"}])
        expect(q[0]["details"]).to include("No path", "Nearest blocked hop: c-egress-to-d -> d-no-ingress",
          "d-no-ingress has no ingress rule that allows c-egress-to-d", "missing side is the ingress of d-no-ingress")
        expect(q[1]["details"]).to include("g-public has no egress rule that allows r-ingress-from-g", "missing side is the egress of g-public")
        expect(q[2]["details"]).to include("Egress on e-egress-443-to-f allows 443/tcp", "ingress on f-ingress-22-from-e allows 22/tcp", "nothing in common")
        expect(q.map { |x| x["pathEdges"] }).to all(be_empty)
        expect(q.map { |x| x["dimmed"] }).to all(eq(0))
      end

      it "intersects ports, ranges and protocols per hop, and filters by port" do
        q = answers([{from: "wide-egress", to: "range-ingress"}, {from: "wide-egress", to: "range-ingress", port: "1600"},
          {from: "wide-egress", to: "range-ingress", port: "1600/udp"}, {from: "pinger-egress", to: "ping-ingress", port: "icmp"},
          {from: "pinger-egress", to: "ping-ingress", port: "icmp 3"}, {from: "web", to: "db", port: "5432"},
          {from: "web", to: "db", port: "80"}, {from: "0.0.0.0/0", to: "db", port: "443"}])
        expect(q[0]["details"]).to include("Allowed ports: 1500-2000/tcp")
        expect(q[0]["details"]).not_to include("udp")
        expect(q[1]["details"]).to include("Reachable in 1 hop on port 1600", "Every hop allows port 1600")
        expect(q[2]["details"]).to include("No path", "not on port 1600/udp")
        expect(q[3]["details"]).to include("Allowed ports: icmp 8")
        expect(q[4]["details"]).to include("No path", "not on port icmp 3")
        expect(q[5]["details"]).to include("Reachable in 1 hop on port 5432")
        expect(q[6]["details"]).to include("No path", "not on port 80")
        expect(q[7]["details"]).to include("No path", "Nearest blocked hop: web -> db", "web is reachable from 0.0.0.0/0 in 1 hop")
      end

      it "matches CIDR, IPv6 and prefix list sources by containment and never lets them carry traffic onward" do
        q = answers([{from: "10.1.0.0/16", to: "g-public"}, {from: "0.0.0.0/0", to: "h-internal"},
          {from: "2001:db8:1::/48", to: "v6-ingress"}, {from: "0.0.0.0/0", to: "v6-ingress"},
          {from: "pl-123", to: "pl-ingress"}, {from: "10.1.0.0/16", to: "pl-ingress"}, {from: "h-internal", to: "0.0.0.0/0"}])
        expect(q[0]["details"]).to include("Reachable in 1 hop", "80/tcp from 0.0.0.0/0")
        expect(q[0]["pathNodes"]).to eq(%w[10.1.0.0/16 sg-g])
        expect(q[0]["pathEdges"]).to eq(%w[0.0.0.0/0-sg-g])
        expect(q[0]["pathVia"]).to eq(%w[0.0.0.0/0])
        # Only part of 0.0.0.0/0 is inside the 10.1.0.0/16 the group allows.
        expect(q[1]["details"]).to include("Possibly reachable in 1 hop", "covers only part of the addresses of 0.0.0.0/0")
        expect(q[2]["details"]).to include("Reachable in 1 hop", "443/tcp from 2001:db8::/32")
        expect(q[3]["details"]).to include("No path")
        expect(q[4]["details"]).to include("Reachable in 1 hop", "443/tcp from pl-123")
        expect(q[5]["details"]).to include("Possibly reachable in 1 hop", "contents of the prefix list are not in the data")
        expect(q[6]["details"]).to include("Reachable in 1 hop", "all to 0.0.0.0/0")
      end

      it "reports possible, not reachable, when a hop rests on a CIDR or prefix list that cannot be matched to a group" do
        q = answers([{from: "p-egress-to-cidr", to: "q-ingress-from-p"}, {from: "p-egress-to-cidr", to: "t-ingress-from-cidr"}])
        expect(q[0]["details"]).to include("Possibly reachable in 1 hop", "(possible)", "Egress 22/tcp to 192.168.0.0/16 cannot be matched to q-ingress-from-p")
        expect(q[0]["details"]).not_to include("Reachable in")
        expect(q[0]["pathEdges"]).to eq(%w[sg-p-192.168.0.0/16 sg-p-sg-q])
        expect(q[0]["pathVia"]).to eq(%w[192.168.0.0/16])
        expect(q[1]["details"]).to include("Possibly reachable in 1 hop", "Ingress 22/tcp from 192.168.0.0/16 cannot be matched to p-egress-to-cidr")
        expect(q[1]["pathNodes"]).not_to include("192.168.0.0/16")
      end

      it "leaves the answer and the drawn path alone when the Ingress, Egress and Risky only toggles change" do
        r = path_report(render_fixture, [{from: "0.0.0.0/0", to: "db", keep: true},
          {toggle: "#ingress"}, {toggle: "#egress"}, {toggle: "#risky-only"}])
        first, *toggled = r["queries"]
        expect(first["details"]).to include("Reachable in 2 hops")
        toggled.each do |t|
          expect(t["details"]).to eq(first["details"])
          expect(t["pathEdges"]).to eq(first["pathEdges"])
          expect(t["dimmed"]).to eq(first["dimmed"])
        end
      end

      it "answers X to X from the group's own rules" do
        q = answers([{from: "s-self", to: "s-self"}])
        expect(q[0]["details"]).to include("Nearest blocked hop: s-self -> s-self", "missing side is the egress of s-self")
        q = answers([{from: "self", to: "self"}, {from: "lonely", to: "lonely"}], source: adversarial)
        expect(q[0]["details"]).to include("Reachable in 1 hop", "Hop 1: self -> self", "Allowed ports: 22/tcp")
        expect(q[1]["details"]).to include("missing side is the ingress of lonely")
      end

      it "treats 0.0.0.0/0 as covering prefix lists, and keeps IPv4 and IPv6 rules apart" do
        q = answers([{from: "pl-123", to: "anydst"}, {from: "def", to: "pl-123"}, {from: "famsrc", to: "famdst"},
          {from: "v6src", to: "v6dst"}], source: adversarial)
        expect(q[0]["details"]).to include("Reachable in 1 hop", "80/tcp from 0.0.0.0/0")
        expect(q[1]["details"]).to include("Reachable in 1 hop", "all to 0.0.0.0/0")
        expect(q[2]["details"]).to include("No path", "different address families")
        expect(q[3]["details"]).to include("Possibly reachable", "applies only if v6dst has IPv6 addresses")
        expect(q[3]["details"]).not_to include("Reachable in")
      end

      it "keeps the CIDRs behind a name given in the :groups config" do
        groups = AwsSecurityViz::AwsConfig.new(groups: {"10.0.5.0/24" => "Office", "0.0.0.0/0" => "Internet"})
        q = answers([{from: "Office", to: "cdst"}, {from: "def", to: "Office"}, {from: "Internet", to: "anydst"}],
          source: adversarial, config: groups)
        expect(q[0]["details"]).to include("Reachable in 1 hop", "22/tcp from 10.0.0.0/16")
        expect(q[1]["details"]).to include("Reachable in 1 hop")
        expect(q[2]["details"]).to include("Reachable in 1 hop")
      end

      it "calls partly covered ranges and prefix list contents possible, and evaluates such hops directly" do
        q = answers([{from: "10.0.0.0/8", to: "cdst"}, {from: "10.1.0.0/16", to: "pldst"}, {from: "egnarrow", to: "10.0.0.0/8"},
          {from: "egnarrow", to: "10.0.5.7/32"}], source: adversarial)
        expect(q[0]["details"]).to include("Possibly reachable in 1 hop", "covers only part of the addresses of 10.0.0.0/8")
        expect(q[1]["details"]).to include("Possibly reachable in 1 hop", "contents of the prefix list are not in the data")
        expect(q[2]["details"]).to include("Possibly reachable in 1 hop", "covers only part of the addresses of 10.0.0.0/8")
        expect(q[3]["details"]).to include("Reachable in 1 hop")
      end

      it "treats rules that are not in the input as unknown, never as an allow or a deny" do
        q = answers([{from: "sg-ext999", to: "extdst"}, {from: "nokey", to: "nokeydst"}, {from: "noeg", to: "ionly"}], source: adversarial)
        expect(q[0]["details"]).to include("Possibly reachable in 1 hop", "egress rules of sg-ext999 are not in the input")
        expect(q[1]["details"]).to include("Possibly reachable in 1 hop", "egress rules of nokey are not in the input")
        expect(q[2]["details"]).to include("No path", "noeg has no egress rule")
      end

      it "names the blocked hop on the closest path, not the hop between the ends" do
        q = answers([{from: "ma", to: "md"}], source: adversarial)
        expect(q[0]["details"]).to include("Nearest blocked hop: mb -> mc", "mb is reachable from ma in 1 hop", "nothing in common")
        expect(q[0]["details"]).not_to include("ma -> md")
      end

      it "accepts protocol numbers, treats other prefix lists as possible and names the allowed part of a range" do
        q = answers([{from: "def", to: "tdef", port: "proto 6"}, {from: "pl-999", to: "pldst"}], source: adversarial)
        expect(q[0]["details"]).to include("Reachable in 1 hop", "on port proto 6")
        expect(q[1]["details"]).to include("Possibly reachable in 1 hop", "contents of the prefix list are not in the data")
        q = answers([{from: "0.0.0.0/0", to: "h-internal"}])
        expect(q[0]["details"]).to include("only 10.1.0.0/16 of 0.0.0.0/0 is allowed")
      end

      it "rejects a port filter that is not a port, a range, icmp or a protocol" do
        q = answers([{from: "web", to: "db", port: "all"}, {from: "web", to: "db", port: "9-1"}])
        expect(q.map { |x| x["details"] }).to all(include("Unrecognised port"))
      end

      it "offers CIDRs that only egress rules name, even when egress edges are not drawn" do
        q = answers([{from: "egnarrow", to: "10.0.5.7/32"}], source: adversarial, config: AwsSecurityViz::AwsConfig.new(egress: false))
        expect(q[0]["details"]).to include("Reachable in 1 hop", "all to 10.0.0.0/16")
      end

      it "runs from the Find button" do
        q = answers([{from: "web", to: "db", click: true}])
        expect(q[0]["details"]).to include("Reachable in 1 hop")
      end

      it "keeps a hostile group name as text" do
        file = render_fixture
        r = path_report(file, [{from: hostile_name, to: "g-public", tap_background: true}])
        expect_clean(r, file)
        q = r["queries"].first
        expect(q["pathNodes"]).to include("sg-evil")
        expect(q["details"]).to include(hostile_name, "Reachable in 1 hop")
        expect(q["detailsMarkup"]).to eq(0)
        expect(q["pwned"]).to be_nil
        expect(q["after_background_tap"]["details"]).to include(hostile_name)
        expect(q["after_background_tap"]["pathEdges"]).to eq(q["pathEdges"])
      end

      it "says so when a name matches several groups, and lists some" do
        q = answers([{from: "sg-", to: "db"}])
        expect(q[0]["details"]).to include("Ambiguous", "The source matches")
        expect(q[0]["pathEdges"]).to be_empty
      end

      it "reports a missing pick and an unrecognised port" do
        q = answers([{from: "nothing-like-this", to: "db"}, {from: "web", to: "db", port: "banana"}])
        expect(q[0]["details"]).to include("Pick a source and a target")
        expect(q[1]["details"]).to include("Unrecognised port")
      end

      it "leaves the rules out of an obfuscated report and disables the query" do
        render_fixture(renderer: "html")
        obfuscated = AwsSecurityViz::AwsConfig.new(obfuscate: true)
        AwsSecurityViz::VisualizeAws.new(obfuscated, source_file: fixture, renderer: "html").unleash("hidden.html")
        html = File.read("hidden.html")
        data = JSON.parse(html[%r{<script type="application/json" id="graph-data">(.*?)</script>}m, 1])
        expect(data["nodes"].flat_map(&:keys)).not_to include("rules")
        expect(html).not_to include("sg-web")
      end
    end

    describe "a graph over the collapse threshold" do
      let(:vpcs) { 12 }
      let(:per_vpc) { 15 }

      def render_large(file = "large.html")
        renderer = described_class.new(file, config)
        vpcs.times do |v|
          per_vpc.times { |i| renderer.add_node("sg-#{v}-#{i}", {label: "app-#{v}-#{i}", vpc_id: "vpc-#{v}", region: "eu-west-1"}) }
          renderer.add_edge("sg-#{v}-0", "sg-#{v}-1", {color: :blue, label: "443"})
          renderer.add_edge("sg-#{v}-1", "sg-#{(v + 1) % vpcs}-0", {color: :blue, label: "5432", descriptions: [{ports: "5432", text: "db from #{v}"}]})
          renderer.add_edge("sg-#{v}-2", "sg-#{(v + 1) % vpcs}-3", {color: :blue, label: "22"})
        end
        renderer.add_node("0.0.0.0/0", {label: "0.0.0.0/0"})
        renderer.add_edge("0.0.0.0/0", "sg-0-0", {color: :blue, label: "22", risky: true})
        renderer.add_edge("0.0.0.0/0", "sg-0-1", {color: :blue, label: "80"})
        renderer.add_edge("sg-5-4", "sg-5-5", {color: :blue, label: "all", risky: true})
        renderer.output
        file
      end

      def collapse_report(file)
        out = run_browser_script(File.expand_path("support/browser_collapse.py", __dir__), File.expand_path(file), "vpc:eu-west-1|vpc-3", "app-3-7")
        JSON.parse(out.lines.last)
      end

      # The same shape as render_large, built through the real pipeline so the groups carry their rules: in each VPC
      # group 0 may send 443 to group 1, and group 1 sends 5432 to group 0 of the next VPC.
      def render_chain(file = "chain.html")
        perm = ->(port, group: nil, cidr: nil, desc: nil) {
          pair = {"GroupId" => group, "UserId" => "1"}.merge(desc ? {"Description" => desc} : {})
          {"IpProtocol" => "tcp", "FromPort" => port, "ToPort" => port, "IpRanges" => cidr ? [{"CidrIp" => cidr}] : [],
           "Ipv6Ranges" => [], "PrefixListIds" => [], "UserIdGroupPairs" => group ? [pair] : []}
        }
        groups = (0...vpcs).flat_map { |v|
          (0...per_vpc).map { |i|
            ingress = []
            egress = []
            if i.zero?
              egress << perm.call(443, group: "sg-#{v}-1")
              ingress << perm.call(5432, group: "sg-#{(v - 1) % vpcs}-1", desc: "db from #{(v - 1) % vpcs}")
              ingress << perm.call(22, cidr: "0.0.0.0/0") if v.zero?
            elsif i == 1
              ingress << perm.call(443, group: "sg-#{v}-0")
              egress << perm.call(5432, group: "sg-#{(v + 1) % vpcs}-0")
            end
            {"GroupName" => "app-#{v}-#{i}", "GroupId" => "sg-#{v}-#{i}", "VpcId" => "vpc-#{v}", "IpPermissions" => ingress, "IpPermissionsEgress" => egress}
          }
        }
        File.write("chain.json", JSON.generate({"SecurityGroups" => groups}))
        AwsSecurityViz::VisualizeAws.new(config, source_file: "chain.json", renderer: "html").unleash(file)
        file
      end

      def path_report(queries, *flags)
        out = run_browser_script(File.expand_path("support/browser_path.py", __dir__), File.expand_path(render_chain), JSON.generate(queries), *flags)
        JSON.parse(out.lines.last).tap { |r| expect(r["picker"]).to be(true), "the viewer has no #path-from picker" }
      end

      [[], ["--webgl"]].each do |flags|
        it "keeps the highlight and the dimming in step through search, Expand all and collapsing a VPC on the path (#{flags.first || "canvas"})" do
          vpc1 = "vpc:|vpc-1"
          r = path_report([{from: "app-0-0", to: "app-2-1", actions: [
            {do: "search", text: "app-5-3"}, {do: "clear_search"}, {do: "expand_all"}, {do: "dblclick", vpc: vpc1}
          ]}], *flags)
          q = r["queries"].first
          search, _, expand, collapse = q["actions"]
          [search, expand].each do |a|
            expect(a["dimmed"]).to be > 0
            expect(a["pathNodes"]).to eq(q["pathNodes"])
            expect(a["pathEdges"]).to eq(q["pathEdges"])
          end
          # Exactly the path colour, with the view fitted to the path (the whole graph is a few thin lines).
          expect(expand["orange_fit"]).to be > 500
          expect(collapse["pathCollapsed"]).to eq([vpc1])
          expect(collapse["pathNodes"]).to eq(%w[sg-0-0 sg-0-1 sg-2-0 sg-2-1])
          expect(collapse["pathEdges"].size).to be > 0
          expect(collapse["pathEdges"].grep(/\Ameta:/).size).to eq(2)
          expect(collapse["dimmed"]).to be > 0
          expect(collapse["orange_fit"]).to be > 500
          expect(q["dimTextOpacity"]).to be_within(0.001).of(0.12)
          expect(expand["dark"]).to be < r["before"]["dark"]
        end

        it "expands the collapsed VPCs on a path, draws and fits it, and restores the view on clear (#{flags.first || "canvas"})" do
          r = path_report([{from: "app-0-0", to: "app-2-1"}], *flags)
          expect(r["requests"]).to eq(["file://" + File.expand_path("chain.html")])
          expect(r["errors"]).to be_empty
          expect(r["console"].grep(/Content Security Policy|Refused to/)).to be_empty
          expect(r["renderer"]).to eq(flags.empty? ? "canvas" : "webgl")
          q = r["queries"].first
          expect(r["before"]["collapsed"].size).to eq(vpcs)
          expect(q["collapsed"].size).to eq(vpcs - 3)
          expect(q["collapsed"]).not_to include("vpc:|vpc-0", "vpc:|vpc-1", "vpc:|vpc-2")
          expect(q["pathNodes"]).to eq(%w[sg-0-0 sg-0-1 sg-1-0 sg-1-1 sg-2-0 sg-2-1])
          expect(q["details"]).to include("5 hops", "db from 0", "db from 1")
          expect(q["allVisible"]).to be(true)
          expect(q["dimmed"]).to be > 0
          expect(q["orange"]).to be > 200
          expect(q["cleared"]["collapsed"]).to eq(r["before"]["collapsed"])
          expect(q["cleared"]["zoom"]).to be_within(1e-6).of(r["before"]["zoom"])
          expect(q["cleared"]["pan"]["x"]).to be_within(1e-6).of(r["before"]["pan"]["x"])
          expect(q["cleared"]["orange"]).to eq(0)
          expect(q["cleared"]["dimmed"]).to eq(0)
        end
      end

      it "draws the same picture every time the same report is opened" do
        file = render_large
        positions = 2.times.map {
          out = run_browser_script(File.expand_path("support/browser_positions.py", __dir__), File.expand_path(file))
          JSON.parse(out.lines.last)
        }
        expect(positions[0]["load"].size).to be > 12
        expect(positions[1]).to eq(positions[0])
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
        expect(r["expanded_details"]).to include("Double-click to collapse")
        expect(r["group_details"]).to include("Id: sg-3-")
        expect(r["after_recollapse"]["collapsed"].size).to eq(vpcs)
        expect(r["ingress_hidden"]).to be(true)

        expect(r["label_after_expand"]).to eq("vpc-3")
        expect(r["label_after_recollapse"]).to eq("vpc-3 (15 groups)")
        expect(r["collapsed_details"]).to include("Internal rules: 1")
        expect(r["internal_risky_details"]).to include("internal rule(s) are risky")
        expect(r["into_vpc_details"]).to include("5432", "22", "Rule descriptions", "db from 2")
        expect(r["meta_risky_width"]).to eq(5)
        expect(r["peer_meta_label"]).to eq("2 rules")
        expect(r["risky_only_label"]).to eq("1 rule")
        expect(r["risky_only_visible"]).to eq(["meta:0.0.0.0/0>vpc:eu-west-1|vpc-0|ingress"])
        expect(r["risky_only_details"]).to include("22")
        expect(r["risky_only_details"]).not_to include("app-0-1", ": 80")
        expect(r["collapsed_details"]).to include("Rule descriptions", "db from 2", "db from 3")

        expect(r["broad_search_collapsed"]).to eq(vpcs)
        expect(r["enter_search_collapsed"]).to eq(0)
        expect(r["cleared_search_collapsed"]).to eq(vpcs)
        expect(r["expand_all_layouts"]).to eq(1)

        expect(r["search_matches"]).to eq(["sg-3-7"])
        expect(r["search_vpc_collapsed"]).to be(false)

        expect(r["all_expanded"]).to include("collapsed" => [], "meta" => 0)
        expect(r["all_expanded"]["groups"]).to eq(vpcs * per_vpc + 1)
        expect(r["expanded_overlaps"]).to be_empty
        expect(r["all_collapsed"]["collapsed"].size).to eq(vpcs)
      end

      describe "switching layout" do
        let(:kept) { %w[collapsed selected matches hidden details search toggles dimmed] }

        def state_report
          out = run_browser_script(File.expand_path("support/browser_layout_state.py", __dir__), File.expand_path(render_chain), "app-5-3", "sg-5-3", "app-0-0", "app-2-1")
          JSON.parse(out.lines.last).tap { |r| expect(r["picker"]).to be(true), "the viewer has no #layout picker" }
        end

        it "keeps collapse state, the selection, search hits, the toggles and a shown path, on canvas and WebGL" do
          r = state_report
          expect(r["errors"]).to be_empty
          expect(r["console"].grep(/Content Security Policy|Refused to/)).to be_empty
          %w[search_select_toggle search_select_toggle_webgl path].each do |run|
            start = r["runs"][run]["start"]
            expect(start["collapsed"].size).to be < 12 if run == "search_select_toggle"
            expect(start["notFinite"]).to eq(0)
            %w[flow rings grid fcose].each do |layout|
              now = r["runs"][run][layout]
              expect(now["layout"]).to eq(layout)
              expect(now["renderer"]).to eq(start["renderer"])
              kept.each { |key| expect(now[key]).to eq(start[key]), "#{run}/#{layout}: #{key} changed from #{start[key].inspect[0, 120]} to #{now[key].inspect[0, 120]}" }
              expect(now["notFinite"]).to eq(0)
            end
          end
          select = r["runs"]["search_select_toggle"]["start"]
          expect(select["selected"]).to eq(["sg-5-3"])
          expect(select["matches"]).to include("sg-5-3")
          expect(select["details"]).to include("app-5-3")
          expect(select["hidden"]).not_to be_empty
          expect(select["dimmed"]).to be > 0
          expect(select["toggles"]).to eq([false, true, false])
          expect(r["runs"]["search_select_toggle_webgl"]["start"]["renderer"]).to eq("webgl")
          %w[flow rings grid fcose].each { |l| expect(r["runs"]["search_select_toggle"][l]["selectedInView"]).to be(true) }

          path = r["runs"]["path"]
          expect(path["start"]["path"]).not_to be_empty
          %w[start flow rings grid fcose].each do |layout|
            expect(path[layout]["pathInView"]).to be(true), "path: #{layout}: path groups outside the view"
            expect(path[layout]["orange_fit"]).to be > 500, "path: #{layout}: the path is not on screen"
          end
          # Clear path puts the collapsed VPCs back, whatever layout is on.
          expect(r["after_clear"]["path"]).to be_empty
          expect(r["after_clear"]["collapsed"].size).to eq(12)
          expect(r["after_clear"]["orange"]).to eq(0)
        end
      end
    end
  end
end
