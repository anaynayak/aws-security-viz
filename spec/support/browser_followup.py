# Checks details-panel refresh, fitting an expanded VPC, label sizing and re-fitting on resize in headless Chromium.
# Run: uv run --locked --group browser python3 spec/support/browser_followup.py REPORT.html VPC_ID
import json
import sys

from playwright.sync_api import sync_playwright

report, vpc_id = sys.argv[1:3]
out = {"errors": []}

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1440, "height": 900})
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.goto("file://" + report)
    page.wait_for_selector("canvas")

    def ev(js, arg=None):
        return page.evaluate("(arg) => { const r = (" + js + ")(arg); return r && r.cy ? null : r; }", arg)

    FITS = """() => { const cy = awsSecurityViz.cy, b = cy.elements().boundingBox(), e = cy.extent();
      return b.x1 >= e.x1 - 1 && b.x2 <= e.x2 + 1 && b.y1 >= e.y1 - 1 && b.y2 <= e.y2 + 1; }"""

    # Label sizes: what the node is sized for must cover the label as it is drawn.
    out["label_fit"] = ev("""() => {
      const c = document.createElement('canvas').getContext('2d');
      return awsSecurityViz.cy.nodes().filter(n => !n.isParent()).map(n => {
        c.font = n.style('font-weight') + ' ' + n.numericStyle('font-size') + 'px ' + n.style('font-family');
        return [n.id(), n.data('w') - c.measureText(n.data('label')).width];
      }).filter(([, slack]) => slack < 0).map(([id]) => id);
    }""")

    # The panel follows a double-click.
    ev("(id) => { awsSecurityViz.cy.getElementById(id).emit('tap'); return null; }", vpc_id)
    out["details_collapsed"] = ev("() => document.getElementById('details').textContent")
    zoom = ev("() => awsSecurityViz.cy.zoom()")
    ev("(id) => { awsSecurityViz.cy.getElementById(id).emit('dbltap'); return null; }", vpc_id)
    out["details_expanded"] = ev("() => document.getElementById('details').textContent")
    out["expanded_in_view"] = ev("""(id) => { const cy = awsSecurityViz.cy, b = cy.getElementById(id).renderedBoundingBox({includeLabels: false, includeOverlays: false});
      return b.x1 >= 0 && b.y1 >= 0 && b.x2 <= cy.width() && b.y2 <= cy.height(); }""", vpc_id)
    out["zoom_before"] = zoom
    out["zoom_after"] = ev("() => awsSecurityViz.cy.zoom()")
    ev("(id) => { awsSecurityViz.cy.getElementById(id).emit('dbltap'); return null; }", vpc_id)
    out["details_recollapsed"] = ev("() => document.getElementById('details').textContent")

    # A VPC that already fits keeps the zoom.
    page.click("#reset")
    page.click("#expand-all")
    page.click("#collapse-all")
    # Resize: the view is fitted again while the user has not moved it.
    page.click("#reset")
    page.set_viewport_size({"width": 900, "height": 560})
    page.wait_for_timeout(500)
    out["fits_after_resize"] = ev(FITS)
    browser.close()

print(json.dumps(out))
