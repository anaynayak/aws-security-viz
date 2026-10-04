# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

describe AwsSecurityViz::Renderer::Json do
  it "writes a name starting with a pipe as a file instead of running it" do
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        marker = File.join(dir, "ran")
        name = "|touch ran"
        renderer = described_class.new(name, {})
        renderer.add_node("a", {})
        renderer.output
        expect(File.exist?(marker)).to be false
        expect(JSON.parse(File.read(name))["nodes"]).to eq([{"id" => "a", "label" => "a"}])
      end
    end
  end

  it "writes through File rather than IO, which can spawn a command on Ruby 3.3 and 3.4" do
    expect(IO).not_to receive(:write)
    expect(File).to receive(:write).with("out.json", kind_of(String))
    described_class.new("out.json", {}).output
  end
end
