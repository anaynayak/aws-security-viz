# Opens a generated .html report in headless Chromium and prints which nodes start collapsed.
# Run: uv run --locked --group browser python3 spec/support/browser_state.py REPORT.html
import json
import sys

from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto("file://" + sys.argv[1])
    page.wait_for_selector("canvas")
    out = {"collapsed": page.evaluate("awsSecurityViz.cy.nodes('.collapsed').length"), "threshold": page.evaluate("awsSecurityViz.collapseThreshold")}
    browser.close()

print(json.dumps(out))
