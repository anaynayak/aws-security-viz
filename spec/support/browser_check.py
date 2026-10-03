# Drives a generated .html report in headless Chromium and prints a JSON summary.
# Run: uv run --with playwright python spec/support/browser_check.py REPORT.html
import json
import sys

from playwright.sync_api import sync_playwright

report = sys.argv[1]
out = {"requests": [], "dialogs": [], "errors": []}

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.on("request", lambda r: out["requests"].append(r.url))
    page.on("dialog", lambda d: (out["dialogs"].append(d.message), d.dismiss()))
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.goto("file://" + report)
    page.wait_for_selector("canvas")

    out["canvas"] = True
    out["nodes"] = page.evaluate("awsSecurityViz.cy.nodes().map(n => ({id: n.id(), kind: n.data('kind'), parent: n.data('parent') || null, unused: !!n.data('unused')}))")
    out["risky_edges"] = page.evaluate("awsSecurityViz.cy.edges('.risky').map(e => e.id())")

    def tap(selector_js):
        page.evaluate("awsSecurityViz.cy.%s.emit('tap')" % selector_js)
        return page.evaluate("document.getElementById('details').textContent")

    out["node_details"] = tap("getElementById('sg-web')")
    out["edge_details"] = tap("getElementById('sg-web-sg-db')")
    out["hostile_details"] = tap("getElementById('sg-evil')")
    out["details_children_html"] = page.evaluate("document.getElementById('details').innerHTML")
    out["injected"] = page.evaluate("document.querySelectorAll('#details img, #details script, body > img').length")
    out["pwned"] = page.evaluate("window.pwned === undefined ? null : window.pwned")
    out["dimmed_after_focus"] = page.evaluate("awsSecurityViz.cy.elements('.dim').length")

    page.click("#ingress")
    out["ingress_hidden"] = page.evaluate("awsSecurityViz.cy.edges('.ingress').every(e => e.style('display') === 'none')")
    out["egress_visible"] = page.evaluate("awsSecurityViz.cy.edges('.egress').every(e => e.style('display') === 'element')")
    page.click("#ingress")

    page.fill("#search", "evil")
    out["matches"] = page.evaluate("awsSecurityViz.cy.nodes('.match').map(n => n.id())")
    browser.close()

print(json.dumps(out))
