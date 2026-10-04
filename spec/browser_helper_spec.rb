require "spec_helper"

RSpec.describe BrowserHelper do
  it "skips unless BROWSER_SPECS=required, which fails when uv or Chromium is missing" do
    chromium = "BrowserType.launch: Executable doesn't exist at /x"
    expect(described_class.policy(uv_installed: false, required: false)).to eq(:skip)
    expect(described_class.policy(uv_installed: false, required: true)).to eq(:raise)
    expect(described_class.policy(uv_installed: true, stderr: chromium, required: false)).to eq(:skip)
    expect(described_class.policy(uv_installed: true, stderr: chromium, required: true)).to eq(:raise)
    expect(described_class.policy(uv_installed: true, stderr: "Traceback", required: true)).to eq(:run)
    expect(described_class.policy(uv_installed: true, required: true)).to eq(:run)
  end
end
