# frozen_string_literal: true

require "spec_helper"
require "stringio"

describe CliGuard do
  let(:out) { StringIO.new }

  it "returns 0 on success" do
    expect(CliGuard.run(out: out) {}).to eq(0)
  end

  it "exits quietly with 130 on Ctrl-C" do
    expect(CliGuard.run(out: out) { raise Interrupt }).to eq(130)
    expect(out.string).to be_empty
  end

  it "does not swallow exit or signal-style exceptions as errors" do
    expect { CliGuard.run(out: out) { exit 3 } }.to raise_error(SystemExit)
  end

  it "prints a clear message and returns 1 for a missing region" do
    status = CliGuard.run(out: out) { raise Aws::Errors::MissingRegionError }
    expect(status).to eq(1)
    expect(out.string).to include("[ERROR] no AWS region", "AWS_REGION")
  end

  it "prints the service error code for AWS API errors" do
    status = CliGuard.run(out: out) { raise Aws::EC2::Errors::AuthFailure.new(nil, "bad keys") }
    expect(status).to eq(1)
    expect(out.string).to include("[ERROR] AWS AuthFailure: bad keys")
  end

  it "re-raises after printing when debugging" do
    expect { CliGuard.run(debug: true, out: out) { raise "boom" } }.to raise_error("boom")
    expect(out.string).to include("[ERROR] boom")
  end
end
