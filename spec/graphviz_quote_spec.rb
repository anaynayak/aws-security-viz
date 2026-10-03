# frozen_string_literal: true

require "spec_helper"

describe AwsSecurityViz::Renderer::GraphViz, "quoting" do
  it "turns \\r\\n, a lone \\r and \\n all into a DOT newline escape" do
    renderer = described_class.new("x.dot", AwsSecurityViz::AwsConfig.new)
    renderer.add_node("a", label: "one\r\ntwo\rthree\nfour")
    expect(renderer.to_dot).to include('label="one\\ntwo\\nthree\\nfour"')
  end
end
