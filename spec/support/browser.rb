require "open3"

# Runs a Playwright script from spec/support under the locked `browser` uv group (pinned playwright, pillow).
# Locally a missing uv or Chromium makes the example pending; with CI set it fails, so a broken install cannot
# turn the browser job green with everything skipped.
module BrowserHelper
  ROOT = File.expand_path("../..", __dir__)

  def self.missing_tool?(stderr)
    stderr.include?("Executable doesn't exist")
  end

  def self.uv_installed?
    system("which uv > /dev/null 2>&1")
  end

  # Returns :skip, :raise or :run for the given environment.
  def self.policy(uv_installed:, stderr: "", ci: ENV["CI"])
    return :run if stderr.empty? && uv_installed
    return :run unless !uv_installed || missing_tool?(stderr)
    ci ? :raise : :skip
  end

  def run_browser_script(script, *args)
    installed = BrowserHelper.uv_installed?
    handle_missing_tool("uv is not installed", BrowserHelper.policy(uv_installed: installed)) unless installed
    out, err, status = Open3.capture3("uv", "run", "--quiet", "--locked", "--project", BrowserHelper::ROOT,
      "--group", "browser", "python3", script, *args.map(&:to_s))
    unless status.success?
      action = BrowserHelper.policy(uv_installed: true, stderr: err)
      handle_missing_tool("Chromium is not installed (uv run --group browser playwright install chromium)", action)
      raise "browser check failed: #{err}"
    end
    out
  end

  private

  def handle_missing_tool(message, action)
    raise message if action == :raise
    skip message if action == :skip
  end
end

RSpec.configure { |c| c.include BrowserHelper }
