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

  it "has the browser check return null from tap, because Playwright cannot serialise a Cytoscape collection" do
    source = File.read(File.expand_path("support/browser_check.py", __dir__))
    expect(source).to include("emit('tap'); return null")
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
      out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "python", File.expand_path("support/browser_state.py", __dir__), File.expand_path("peers.html"))
      raise "browser check failed: #{err}" unless status.success?
      r = JSON.parse(out.lines.last)
      expect(r["threshold"]).to eq(150)
      expect(r["collapsed"]).to eq(0)
    end

    describe "drawing" do
      def visible_report(file, vpc)
        out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "--with", "pillow", "python",
          File.expand_path("support/browser_visible.py", __dir__), File.expand_path(file), vpc)
        raise "browser check failed: #{err}" unless status.success?
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
        out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "python",
          File.expand_path("support/browser_style.py", __dir__), File.expand_path("report.html"), "web")
        raise "browser check failed: #{err}" unless status.success?
        r = JSON.parse(out.lines.last)
        expect(r["errors"]).to be_empty
        risky = r["styles"]["risky"]
        [r["styles"]["mergedEgress"], r["styles"]["mergedIngress"], r["styles"]["egress"]].each do |other|
          expect(risky["width"]).to be > other["width"]
          expect(risky["color"]).not_to eq(other["color"])
        end
        expect(risky["arrowScale"]).to be > 1
        expect(r["legend"]).to match(/risky public ingress/)
        expect(r["legend"]).not_to include("thick dashed")
      end

      def followup_report(file, vpc)
        out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "python",
          File.expand_path("support/browser_followup.py", __dir__), File.expand_path(file), vpc)
        raise "browser check failed: #{err}" unless status.success?
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
        out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "python",
          File.expand_path("support/browser_style.py", __dir__), File.expand_path("report.html"), "sg-db")
        raise "browser check failed: #{err}" unless status.success?
        r = JSON.parse(out.lines.last)
        expect(r["search_matches"]).to eq(1)
        expect(r["search_zoom"]).to be <= 1.5
        expect(r["search_match_in_view"]).to be(true)
      end
    end

    describe "the WebGL renderer" do
      def webgl_report(file, *flags)
        out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "python",
          File.expand_path("support/browser_webgl.py", __dir__), File.expand_path(file), *flags)
        raise "browser check failed: #{err}" unless status.success?
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
      def path_report(file, queries, *flags)
        out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "--with", "pillow", "python",
          File.expand_path("support/browser_path.py", __dir__), File.expand_path(file), JSON.generate(queries), *flags)
        raise "browser check failed: #{err}" unless status.success?
        JSON.parse(out.lines.last)
      end

      def expect_clean(r, file)
        expect(r["requests"]).to eq(["file://" + File.expand_path(file)])
        expect(r["errors"]).to be_empty
        expect(r["console"].grep(/Content Security Policy|Refused to/)).to be_empty
        expect(r["dialogs"]).to be_empty
      end

      it "finds a path along rule direction, draws it and lists each hop with ports and descriptions" do
        render
        r = path_report("report.html", [{from: "0.0.0.0/0", to: "db"}])
        expect_clean(r, "report.html")
        q = r["queries"].first
        expect(q["pathNodes"]).to eq(%w[0.0.0.0/0 sg-db sg-web])
        expect(q["pathEdges"].size).to eq(2)
        expect(q["details"]).to include("2 hops", "Hop 1", "0.0.0.0/0 -> web", "22", "Hop 2", "web -> db", "5432", "not computed")
        expect(q["details"]).to include("risky")
        expect(q["dimmed"]).to be > 0
        expect(q["allVisible"]).to be(true)
        expect(q["orange"]).to be > 200
        expect(r["before"]["orange"]).to eq(0)
        expect(q["cleared"]["dimmed"]).to eq(0)
        expect(q["cleared"]["pathEdges"]).to be_empty
        expect(q["cleared"]["orange"]).to eq(0)
        expect(q["cleared"]["inputs"]).to eq(["", "", ""])
        expect(q["cleared"]["zoom"]).to eq(r["before"]["zoom"])
        expect(q["cleared"]["pan"]).to eq(r["before"]["pan"])
      end

      it "runs from the Find button and reports no path against the rule direction" do
        render
        r = path_report("report.html", [{from: "db", to: "0.0.0.0/0", click: true}])
        q = r["queries"].first
        expect(q["details"]).to include("No path", "db", "0.0.0.0/0")
        expect(q["pathEdges"]).to be_empty
        expect(q["dimmed"]).to eq(0)
        expect(q["orange"]).to eq(0)
      end

      it "only considers edges that allow the given port" do
        render
        r = path_report("report.html", [
          {from: "0.0.0.0/0", to: "db", port: "5432"},
          {from: "sg-evil", to: "db", port: "5432"},
          {from: "sg-evil", to: "db", port: "22"}
        ])
        expect(r["queries"][0]["pathEdges"]).to be_empty
        expect(r["queries"][0]["details"]).to include("No path", "5432")
        expect(r["queries"][1]["pathNodes"]).to eq(%w[sg-db sg-evil sg-web])
        expect(r["queries"][1]["details"]).to include("on port 5432")
        expect(r["queries"][2]["pathEdges"]).to be_empty
        expect(r["queries"][2]["details"]).to include("No path")
      end

      it "respects the Ingress toggle" do
        render
        r = path_report("report.html", [{from: "0.0.0.0/0", to: "db", keep: true}, {toggle: "#ingress"}])
        expect(r["queries"][0]["pathEdges"].size).to eq(2)
        expect(r["queries"][1]["pathEdges"]).to be_empty
        expect(r["queries"][1]["details"]).to include("No path")
      end

      it "keeps a hostile group name as text" do
        render
        r = path_report("report.html", [{from: hostile, to: "db", tap_background: true}])
        expect_clean(r, "report.html")
        q = r["queries"].first
        expect(q["pathNodes"]).to include("sg-evil")
        expect(q["details"]).to include(hostile)
        expect(q["detailsMarkup"]).to eq(0)
        expect(q["pwned"]).to be_nil
        expect(q["after_background_tap"]["details"]).to include(hostile)
        expect(q["after_background_tap"]["pathEdges"]).to eq(q["pathEdges"])
      end

      it "reports when a picker names no group" do
        render
        r = path_report("report.html", [{from: "nothing-like-this", to: "db"}])
        expect(r["queries"].first["details"]).to include("Pick a source and a target")
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
        out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "python",
          File.expand_path("support/browser_collapse.py", __dir__), File.expand_path(file), "vpc:eu-west-1|vpc-3", "app-3-7")
        raise "browser check failed: #{err}" unless status.success?
        JSON.parse(out.lines.last)
      end

      def path_report(queries, *flags)
        out, err, status = Open3.capture3("uv", "run", "--quiet", "--with", "playwright", "--with", "pillow", "python",
          File.expand_path("support/browser_path.py", __dir__), File.expand_path(render_large), JSON.generate(queries), *flags)
        raise "browser check failed: #{err}" unless status.success?
        JSON.parse(out.lines.last)
      end

      [[], ["--webgl"]].each do |flags|
        it "expands the collapsed VPCs on a path, draws and fits it, and restores the view on clear (#{flags.first || "canvas"})" do
          r = path_report([{from: "app-0-0", to: "app-2-1"}], *flags)
          expect(r["requests"]).to eq(["file://" + File.expand_path("large.html")])
          expect(r["errors"]).to be_empty
          expect(r["console"].grep(/Content Security Policy|Refused to/)).to be_empty
          expect(r["renderer"]).to eq(flags.empty? ? "canvas" : "webgl")
          q = r["queries"].first
          expect(r["before"]["collapsed"].size).to eq(vpcs)
          expect(q["collapsed"].size).to eq(vpcs - 3)
          expect(q["collapsed"]).not_to include("vpc:eu-west-1|vpc-0", "vpc:eu-west-1|vpc-1", "vpc:eu-west-1|vpc-2")
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
    end
  end
end
