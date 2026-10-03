# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "open3"

describe AwsSecurityViz::Renderer::Mermaid do
  let(:config) { AwsSecurityViz::AwsConfig.new }
  let(:renderer) { described_class.new("x.mmd", config) }

  def build
    renderer.add_node('sg-1"<b>#', {label: "web \"x\"\nline <i>", vpc_id: "vpc-1", region: "eu-west-1"})
    renderer.add_node("sg-2", {label: "db", vpc_id: "vpc-1", region: "eu-west-1"})
    renderer.add_node("sg-3", {label: "loose"})
    renderer.add_edge('sg-1"<b>#', "sg-2", label: "5432/tcp", color: :blue)
    renderer.add_edge("0.0.0.0/0", "sg-3", label: "22/tcp", color: :blue, risky: true)
    renderer.to_mermaid
  end

  it "writes a flowchart with generated ids, region and VPC subgraphs, and escaped labels" do
    expect(build).to eq(<<~MMD)
      flowchart LR
        subgraph g1["eu-west-1"]
          subgraph g2["vpc-1"]
            n0["web #quot;x#quot; line #lt;i#gt;"]
            n1["db"]
          end
        end
        n2["loose"]
        n3["0.0.0.0/0"]
        n0 -->|"5432/tcp"| n1
        n3 -->|"22/tcp"| n2
        linkStyle 0 stroke:#1f5fbf
        linkStyle 1 stroke:#dc143c,stroke-width:4px,stroke-dasharray:6 3
    MMD
  end

  it "never puts raw ids in the output" do
    expect(build).not_to include("sg-1", "<b>")
  end

  it "defaults to a .mmd file name and is selectable as a renderer" do
    expect(AwsSecurityViz::Renderer.default_file("mermaid")).to eq("aws-security-viz.mmd")
    expect(AwsSecurityViz::Renderer.pick("mermaid", "x.mmd", config)).to be_a(described_class)
  end

  it "hashes names, ids and ports under obfuscation" do
    Dir.mktmpdir { |dir|
      out = File.join(dir, "o.mmd")
      source = File.expand_path("integration/dummy.json", __dir__)
      obfuscated = AwsSecurityViz::AwsConfig.new(obfuscate: true)
      AwsSecurityViz::VisualizeAws.new(obfuscated, source_file: source, renderer: "mermaid").unleash(out)
      expect(File.read(out)).to start_with("flowchart LR").and(satisfy { |t| !t.match?(/vpc-|sg-/) })
    }
  end

  it "parses with mermaid-cli when it is installed", if: system("which mmdc > /dev/null 2>&1") do
    Dir.mktmpdir { |dir|
      File.write(File.join(dir, "in.mmd"), build)
      _, err, status = Open3.capture3("mmdc", "-i", File.join(dir, "in.mmd"), "-o", File.join(dir, "out.svg"))
      expect(status).to be_success, err
    }
  end
end
