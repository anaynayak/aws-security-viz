# Loads a generated .html report, then runs Expand all and Collapse all, and prints the node positions after each step.
# Two loads of the same report must print the same positions.
# Run: uv run --locked --group browser python3 spec/support/browser_positions.py REPORT.html
import json
import sys

from playwright.sync_api import sync_playwright

out = {}
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1440, "height": 900})
    page.goto("file://" + sys.argv[1])
    page.wait_for_selector("canvas")
    positions = "() => Object.fromEntries(awsSecurityViz.cy.nodes().map(n => [n.id(), [Math.round(n.position().x * 100) / 100, Math.round(n.position().y * 100) / 100]]))"
    out["load"] = page.evaluate(positions)
    page.click("#expand-all")
    out["expand_all"] = page.evaluate(positions)
    page.click("#collapse-all")
    out["collapse_all"] = page.evaluate(positions)
    browser.close()
print(json.dumps(out))
