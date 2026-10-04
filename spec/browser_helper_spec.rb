require "spec_helper"

RSpec.describe BrowserHelper do
  it "skips locally and fails in CI when uv or Chromium is missing" do
    chromium = "BrowserType.launch: Executable doesn't exist at /x"
    expect(described_class.policy(uv_installed: false, ci: nil)).to eq(:skip)
    expect(described_class.policy(uv_installed: false, ci: "true")).to eq(:raise)
    expect(described_class.policy(uv_installed: true, stderr: chromium, ci: nil)).to eq(:skip)
    expect(described_class.policy(uv_installed: true, stderr: chromium, ci: "true")).to eq(:raise)
    expect(described_class.policy(uv_installed: true, stderr: "Traceback", ci: "true")).to eq(:run)
    expect(described_class.policy(uv_installed: true, ci: "true")).to eq(:run)
  end
end
