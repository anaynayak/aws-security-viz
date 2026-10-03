# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "tmpdir"

RSpec::Matchers.define :be_graph_with do |nodes|
  match do |graphv|
    graphv.nodes.keys == nodes
  end
end

describe AwsSecurityViz::VisualizeAws do
  let(:opts) {
    {
      source_file: source_file,
      filename: temp_file
    }
  }
  let(:source_file) { File.join(File.dirname(__FILE__), "dummy.json") }
  let(:config) { AwsSecurityViz::AwsConfig.new({groups: {"0.0.0.0/0" => "*"}}) }
  let(:expected_content) { File.read(expected_file) }
  let(:actual_content) { temp_file.read }

  context "json to dot file" do
    let(:temp_file) { Tempfile.new(%w[aws .dot]) }
    let(:layout_attrs) { Set.new(%w[pos lp xlp head_lp tail_lp bb width height]) }

    # Parses laid-out DOT into structure only (nodes, edges, labels, styling),
    # dropping coordinates and sizes that vary with the Graphviz version and fonts.
    def statements_of(dot)
      dot.scan(/^\s*([^\s\[{}][^\[\n]*?)\s*\[(.*?)\];/m).to_h do |name, attrs|
        pairs = attrs.scan(/(\w+)=("(?:[^"\\]|\\.)*"|[^,\s\]]+)/)
        kept = pairs.map { |k, v| [k, v.delete('"')] }.to_h.except(*layout_attrs)
        [name.delete('"'), kept]
      end
    end

    it "should render nodes, edges and labels as dot" do
      AwsSecurityViz::VisualizeAws.new(config, opts).unleash(temp_file.path)
      edge = {"color" => "blue", "style" => "bold"}
      expect(statements_of(actual_content)).to eq(
        "graph" => {"concentrate" => "true", "overlap" => "false", "rankdir" => "LR", "sep" => "1", "splines" => "true"},
        "sg-appgrp" => {"label" => "app"},
        "sg-dbgrp" => {"label" => "db"},
        "sg-appgrp -> sg-dbgrp" => edge.merge("label" => "5984/tcp"),
        "8.8.8.8/32" => {"label" => "8.8.8.8/32"},
        "8.8.8.8/32 -> sg-appgrp" => edge.merge("label" => "80/tcp"),
        "sg-amzelb" => {"label" => "amazon-elb-sg"},
        "sg-amzelb -> sg-appgrp" => edge.merge("label" => "80/tcp"),
        "*" => {"label" => "*"},
        "* -> sg-appgrp" => edge.merge("label" => "22/tcp", "color" => "crimson", "style" => "dashed", "penwidth" => "3")
      )
    end

    it "writes dot without needing graphviz on PATH" do
      stub_const("ENV", ENV.to_h.merge("PATH" => ""))
      AwsSecurityViz::VisualizeAws.new(config, opts).unleash(temp_file.path)
      expect(actual_content).to start_with('digraph "G" {').and include('"sg-appgrp" -> "sg-dbgrp"')
    end

    it "fails clearly, without writing the file, when graphviz is missing for an image format" do
      png = Tempfile.new(%w[aws .png])
      stub_const("ENV", ENV.to_h.merge("PATH" => ""))
      File.delete(png.path)
      expect { AwsSecurityViz::VisualizeAws.new(config, opts.merge(filename: png)).unleash(png.path) }
        .to raise_error(ArgumentError, "Graphviz 'dot' not found; install graphviz")
      expect(File.exist?(png.path)).to be(false)
    end

    it "fails clearly, without calling dot, for a missing or unknown output extension" do
      expect(Open3).not_to receive(:capture3)
      ["out", "out.xyz"].each do |name|
        renderer = AwsSecurityViz::Renderer::GraphViz.new(File.join(Dir.tmpdir, name), config)
        expect { renderer.output }.to raise_error(ArgumentError, /cannot pick an output format.*\.html, \.json, \.mmd, \.dot\/\.gv.*\.png, \.svg, \.pdf/)
      end
    end

    it "lists .json once in the supported extensions" do
      renderer = AwsSecurityViz::Renderer::GraphViz.new(File.join(Dir.tmpdir, "out.xyz"), config)
      expect { renderer.output }.to raise_error(ArgumentError) { |e| expect(e.message.scan(".json").size).to eq(1) }
    end

    it "finds dot through PATHEXT variants such as dot.exe" do
      Dir.mktmpdir { |dir|
        exe = File.join(dir, "dot.exe")
        File.write(exe, "")
        File.chmod(0o755, exe)
        stub_const("ENV", ENV.to_h.merge("PATH" => dir, "PATHEXT" => ".COM:.EXE"))
        svg = Tempfile.new(%w[aws .svg])
        expect(Open3).to receive(:capture3)
          .and_return(["<svg/>", "", instance_double(Process::Status, success?: true)])
        AwsSecurityViz::VisualizeAws.new(config, opts.merge(filename: svg)).unleash(svg.path)
        expect(File.read(svg.path)).to eq("<svg/>")
      }
    end

    it "renders svg through dot with the configured layout engine" do
      svg = Tempfile.new(%w[aws .svg])
      neato = AwsSecurityViz::AwsConfig.new({groups: {"0.0.0.0/0" => "*"}, layout: "neato"})
      expect(Open3).to receive(:capture3)
        .with("dot", "-Tsvg", "-Kneato", hash_including(:stdin_data))
        .and_return(["<svg/>", "", instance_double(Process::Status, success?: true)])
      AwsSecurityViz::VisualizeAws.new(neato, opts.merge(filename: svg)).unleash(svg.path)
      expect(File.read(svg.path)).to eq("<svg/>")
    end

    it "renders a real svg when dot is installed", if: system("which dot > /dev/null 2>&1") do
      svg = Tempfile.new(%w[aws .svg])
      AwsSecurityViz::VisualizeAws.new(config, opts.merge(filename: svg)).unleash(svg.path)
      expect(File.read(svg.path)).to include("<svg")
    end

    it "escapes quotes, backslashes and newlines in ids and labels" do
      renderer = AwsSecurityViz::Renderer::GraphViz.new("x.dot", config)
      renderer.add_node('a"b\\c', {label: "say \"hi\"\nnow", vpc_id: 'vpc"1'})
      renderer.add_edge('a"b\\c', "d e", label: "80/tcp")
      dot = renderer.to_dot
      expect(dot).to include('subgraph "cluster_vpc\\"1"')
      expect(dot).to include('"a\\"b\\\\c" [label="say \\"hi\\"\\nnow"];')
      expect(dot).to include('"a\\"b\\\\c" -> "d e" [style="bold", label="80/tcp"];')
    end
  end

  context "json to json file" do
    let(:expected_file) { File.join(File.dirname(__FILE__), "expected.json") }
    let(:temp_file) { Tempfile.new(%w[aws .json]) }

    it "should parse json input" do
      AwsSecurityViz::VisualizeAws.new(config, opts.merge(renderer: "json")).unleash(temp_file.path)
      expect(JSON.parse(expected_content)).to eq(JSON.parse(actual_content))
    end

    it "should parse json input with obfuscation" do
      config = AwsSecurityViz::AwsConfig.new({groups: {"0.0.0.0/0" => "*"}, obfuscate: true})
      AwsSecurityViz::VisualizeAws.new(config, opts.merge(renderer: "json")).unleash(temp_file.path)
      expect(actual_content).not_to include('"amazon-elb-sg"', '"app"', '"db"', "sg-appgrp")
    end
  end

  if ENV["TEST_ACCESS_KEY"]
    context "ec2 to json file" do
      let(:expected_file) { File.join(File.dirname(__FILE__), "aws_expected.json") }
      let(:temp_file) { Tempfile.new(%w[aws .json]) }
      let(:opts) {
        {
          filename: temp_file,
          secret_key: ENV["TEST_SECRET_KEY"],
          access_key: ENV["TEST_ACCESS_KEY"],
          region: "us-east-1"
        }
      }

      it "should read from ec2 account", integration: true do
        AwsSecurityViz::VisualizeAws.new(config, opts).unleash(temp_file.path)
        expect(JSON.parse(expected_content)["edges"]).to match_array(JSON.parse(actual_content)["edges"])
        expect(JSON.parse(expected_content)["nodes"]).to match_array(JSON.parse(actual_content)["nodes"])
      end
    end
  end
end
