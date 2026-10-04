# Prints the classes of every node of a report, so a spec can see which peers were drawn as CIDRs, prefix lists or the internet.
# Run: uv run --locked --group browser python3 spec/support/browser_peers.py REPORT.html
import json
import sys

from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    errors = []
    page.on("pageerror", lambda e: errors.append(str(e)))
    page.goto("file://" + sys.argv[1])
    page.wait_for_selector("canvas")
    classes = page.evaluate("awsSecurityViz.cy.nodes().map(n => n.classes())")
    browser.close()
print(json.dumps({"classes": classes, "errors": errors}))
