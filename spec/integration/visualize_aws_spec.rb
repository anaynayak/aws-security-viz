# frozen_string_literal: true

require "spec_helper"
require "tempfile"

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
        "node" => {"label" => '\\N'},
        "sg-appgrp" => {"label" => "app"},
        "sg-dbgrp" => {"label" => "db"},
        "sg-appgrp -> sg-dbgrp" => edge.merge("label" => "5984/tcp"),
        "8.8.8.8/32" => {"label" => "8.8.8.8/32"},
        "8.8.8.8/32 -> sg-appgrp" => edge.merge("label" => "80/tcp"),
        "sg-amzelb" => {"label" => "amazon-elb-sg"},
        "sg-amzelb -> sg-appgrp" => edge.merge("label" => "80/tcp"),
        "*" => {"label" => "*"},
        "* -> sg-appgrp" => edge.merge("label" => "22/tcp")
      )
    end

    it "should parse json input with stubbed out graphviz" do
      nodes = ["sg-appgrp", "8.8.8.8/32", "sg-amzelb", "*", "sg-dbgrp"]
      expect(Graphviz).to receive(:output).with(be_graph_with(nodes), path: temp_file.path, format: nil, dot: "dot")
      AwsSecurityViz::VisualizeAws.new(config, opts).unleash(temp_file.path)
    end

    it "fails clearly, without writing the file, when the layout engine is missing" do
      missing = AwsSecurityViz::AwsConfig.new({groups: {"0.0.0.0/0" => "*"}, layout: "neato"})
      stub_const("ENV", ENV.to_h.merge("PATH" => ""))
      File.delete(temp_file.path)
      expect { AwsSecurityViz::VisualizeAws.new(missing, opts).unleash(temp_file.path) }
        .to raise_error(ArgumentError, "Graphviz 'neato' not found; install graphviz")
      expect(File.exist?(temp_file.path)).to be(false)
    end

    it "passes the configured layout engine to graphviz" do
      neato = AwsSecurityViz::AwsConfig.new({groups: {"0.0.0.0/0" => "*"}, format: "neato"})
      expect(Graphviz).to receive(:output).with(anything, path: temp_file.path, format: nil, dot: "neato")
      AwsSecurityViz::VisualizeAws.new(neato, opts).unleash(temp_file.path)
    end

    it "prefers the layout option over opts.yml format" do
      neato = AwsSecurityViz::AwsConfig.new({groups: {"0.0.0.0/0" => "*"}, format: "dot", layout: "sfdp"})
      expect(Graphviz).to receive(:output).with(anything, path: temp_file.path, format: nil, dot: "sfdp")
      AwsSecurityViz::VisualizeAws.new(neato, opts).unleash(temp_file.path)
    end
  end

  context "json to json file" do
    let(:expected_file) { File.join(File.dirname(__FILE__), "expected.json") }
    let(:temp_file) { Tempfile.new(%w[aws .json]) }

    it "should parse json input" do
      expect(FileUtils).to receive(:copy)
      AwsSecurityViz::VisualizeAws.new(config, opts.merge(renderer: "json")).unleash(temp_file.path)
      expect(JSON.parse(expected_content)).to eq(JSON.parse(actual_content))
    end

    it "should parse json input with obfuscation" do
      config = AwsSecurityViz::AwsConfig.new({groups: {"0.0.0.0/0" => "*"}, obfuscate: true})
      expect(FileUtils).to receive(:copy)
      AwsSecurityViz::VisualizeAws.new(config, opts.merge(renderer: "json")).unleash(temp_file.path)
      expect(actual_content).not_to include('"amazon-elb-sg"', '"app"', '"db"', "sg-appgrp")
    end
  end

  context "json to navigator file" do
    let(:expected_file) { File.join(File.dirname(__FILE__), "navigator.json") }
    let(:temp_file) { Tempfile.new(%w[aws .json]) }

    it "should parse json input" do
      expect(FileUtils).to receive(:copy)
      AwsSecurityViz::VisualizeAws.new(config, opts.merge(renderer: "navigator")).unleash(temp_file.path)
      expect(JSON.parse(expected_content)).to eq(JSON.parse(actual_content))
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
        expect(FileUtils).to receive(:copy)
        AwsSecurityViz::VisualizeAws.new(config, opts).unleash(temp_file.path)
        expect(JSON.parse(expected_content)["edges"]).to match_array(JSON.parse(actual_content)["edges"])
        expect(JSON.parse(expected_content)["nodes"]).to match_array(JSON.parse(actual_content)["nodes"])
      end
    end
  end
end
