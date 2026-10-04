# Reads viewer styles and the search zoom in headless Chromium and prints a JSON summary.
# Run: uv run --locked --group browser python3 spec/support/browser_style.py REPORT.html SEARCH_TEXT
import json
import sys

from playwright.sync_api import sync_playwright

report, query = sys.argv[1:3]
out = {"errors": []}

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1440, "height": 900})
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.goto("file://" + report)
    page.wait_for_selector("canvas")
    out["styles"] = page.evaluate("""() => {
      const cy = awsSecurityViz.cy;
      const [a, b] = cy.nodes('[kind = "group"]').toArray();
      const read = (classes) => {
        const e = cy.add({group: 'edges', data: {id: 'probe-' + classes, source: a.id(), target: b.id()}, classes: classes});
        const s = {width: e.numericStyle('width'), color: e.style('line-color'), arrowScale: e.numericStyle('arrow-scale')};
        cy.remove(e);
        return s;
      };
      return {risky: read('ingress risky'), mergedEgress: read('meta egress'), mergedIngress: read('meta ingress'), egress: read('egress')};
    }""")
    out["legend"] = page.evaluate("document.getElementById('legend').textContent")
    page.fill("#search", query)
    page.wait_for_timeout(300)
    out["search_matches"] = page.evaluate("awsSecurityViz.cy.nodes('.match').length")
    out["search_zoom"] = page.evaluate("awsSecurityViz.cy.zoom()")
    out["search_match_in_view"] = page.evaluate("""() => { const cy = awsSecurityViz.cy, n = cy.nodes('.match')[0], p = n.renderedPosition();
      return p.x > 0 && p.y > 0 && p.x < cy.width() && p.y < cy.height(); }""")
    browser.close()

print(json.dumps(out))
