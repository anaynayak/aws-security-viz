# frozen_string_literal: true

require "spec_helper"

RSpec.describe "AwsSecurityViz namespace" do
  let(:root) { File.expand_path("..", __dir__) }

  it "keeps the library constants out of the global namespace" do
    names = %i[VisualizeAws Graph GraphFilter Traffic SecurityGroup SecurityGroups Peer Rule
      Renderer Json Ec2 Ec2Provider JsonProvider PortLabel AwsConfig CliGuard Exclusions CidrGroupMapping]
    expect(names.select { |name| Object.const_defined?(name, false) }).to be_empty
  end

  it "only has the entry point at the lib root" do
    expect(Dir.children(File.join(root, "lib"))).to contain_exactly("aws_security_viz.rb", "aws_security_viz")
  end

  it "does not use load-path requires inside the gem" do
    sources = Dir[File.join(root, "lib/**/*.rb")].select { |f| File.read(f).match?(/^require "(version|aws_security_viz)/) }
    expect(sources).to be_empty
  end
end
