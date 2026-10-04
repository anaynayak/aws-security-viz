# Checks, in headless Chromium with real mouse input and screenshot pixels, that labels are hidden when the graph is
# zoomed out, an edge's port label appears on hover and while selected, and selecting a node fades (not hides) the rest.
# Prints a JSON summary.
# Run: uv run --locked --group browser python3 spec/support/browser_readability.py REPORT.html
import io
import json
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

report = sys.argv[1]
out = {"errors": []}


def grey(png):
    # Label text is grey or black anti-aliased on white: neither coloured (edges, nodes) nor near white (backgrounds).
    img = Image.open(io.BytesIO(png)).convert("RGB")
    raw = img.tobytes()
    return sum(1 for r, g, b in zip(raw[0::3], raw[1::3], raw[2::3]) if max(r, g, b) - min(r, g, b) <= 20 and r < 200)


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1440, "height": 900})
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.goto("file://" + report)
    page.wait_for_selector("canvas")
    page.wait_for_timeout(500)

    def ev(js, arg=None):
        return page.evaluate("(arg) => { const r = (" + js + ")(arg); return r && r.cy ? null : r; }", arg)

    out["zoom_in"] = ev("() => awsSecurityViz.cy.zoom()")
    out["grey_in"] = grey(page.locator("#cy").screenshot())

    def find_spot():
        # An edge whose midpoint is clear of every node, so the pixels there can only be its label.
        return ev("""() => {
          const cy = awsSecurityViz.cy, r = document.getElementById('cy').getBoundingClientRect();
          const nodes = cy.nodes().filter(n => !n.isParent());
          for (const e of cy.edges().toArray()) {
            const m = e.midpoint(), z = cy.zoom(), p = cy.pan();
            const x = m.x * z + p.x, y = m.y * z + p.y;
            if (x < 30 || y < 30 || x > cy.width() - 30 || y > cy.height() - 30) continue;
            const clear = nodes.every(n => { const b = n.renderedBoundingBox({includeLabels: true}); return x + 24 < b.x1 || x - 24 > b.x2 || y + 12 < b.y1 || y - 12 > b.y2; });
            if (clear && e.data('label')) return {id: e.id(), label: e.data('label'), x: r.left + x, y: r.top + y};
          }
          return null;
        }""")

    spot = find_spot()
    out["spot"] = spot
    clip = {"x": spot["x"] - 24, "y": spot["y"] - 12, "width": 48, "height": 24}
    page.mouse.move(5, 5)
    out["label_before_hover"] = grey(page.screenshot(clip=clip))
    page.mouse.move(spot["x"] - 3, spot["y"])
    page.mouse.move(spot["x"], spot["y"])
    page.wait_for_timeout(300)
    out["hovered"] = ev("() => awsSecurityViz.cy.edges('.hover').map(e => e.id())")
    out["label_on_hover"] = grey(page.screenshot(clip=clip))
    page.mouse.click(spot["x"], spot["y"])
    page.mouse.move(5, 5)
    page.wait_for_timeout(300)
    out["selected"] = ev("() => awsSecurityViz.cy.elements(':selected').map(e => e.id())")
    out["label_selected"] = grey(page.screenshot(clip=clip))

    # Select a node: the rest fades.
    page.click("#reset")
    node = ev("""() => {
      const cy = awsSecurityViz.cy, r = document.getElementById('cy').getBoundingClientRect();
      const n = cy.nodes('[kind = "group"]').filter(n => n.degree() > 2)[0];
      const p = n.renderedPosition();
      return {id: n.id(), x: r.left + p.x, y: r.top + p.y};
    }""")
    page.mouse.move(node["x"], node["y"])
    page.mouse.click(node["x"], node["y"])
    page.mouse.move(5, 5)
    page.wait_for_timeout(300)
    out["faded"] = ev("""() => {
      const dim = awsSecurityViz.cy.elements('.dim');
      return {count: dim.length, total: awsSecurityViz.cy.elements().length,
        opacities: dim.map(e => e.numericStyle('opacity')), shown: dim.every(e => e.style('display') !== 'none' && e.visible())};
    }""")
    out["neighbour_labels"] = ev("() => awsSecurityViz.cy.edges('.show-label').length")

    # Zoom out with the real wheel: labels disappear.
    page.click("#reset")
    page.mouse.move(500, 450)
    for _ in range(400):
        if ev("() => awsSecurityViz.cy.zoom()") < 0.22:
            break
        page.mouse.wheel(0, 20000)
        page.wait_for_timeout(15)
    page.wait_for_timeout(300)
    out["zoom_out"] = ev("() => awsSecurityViz.cy.zoom()")
    out["grey_out"] = grey(page.locator("#cy").screenshot())

    # Zoomed out, an edge you hover or select, and the node you select with its neighbours, are still labelled.
    page.mouse.move(5, 5)
    spot = find_spot()
    clip = {"x": spot["x"] - 24, "y": spot["y"] - 12, "width": 48, "height": 24}
    out["out_label_before_hover"] = grey(page.screenshot(clip=clip))
    page.mouse.move(spot["x"] - 3, spot["y"])
    page.mouse.move(spot["x"], spot["y"])
    page.wait_for_timeout(300)
    # At this zoom a label is two or three pixels high, too few to tell from the edge's own anti-aliased pixels on every platform,
    # and edges lie on top of each other, so the pointer may pick a neighbour of the edge aimed at: read the style of the hovered one.
    out["out_hover_label"] = ev("""() => {
      const e = awsSecurityViz.cy.edges('.hover')[0];
      if (!e) return null;
      return {id: e.id(), label: e.style('label'), data: e.data('label'), minZoomed: e.numericStyle('min-zoomed-font-size'), opacity: e.numericStyle('text-opacity')};
    }""")
    page.mouse.move(5, 5)
    node = ev("""() => {
      const cy = awsSecurityViz.cy, r = document.getElementById('cy').getBoundingClientRect();
      const n = cy.nodes('[kind = "group"]').filter(n => n.degree() > 2 && n.renderedPosition().x > 20 && n.renderedPosition().y > 20)[0];
      const p = n.renderedPosition();
      return {id: n.id(), x: r.left + p.x, y: r.top + p.y};
    }""")
    page.mouse.move(node["x"] - 2, node["y"])
    page.mouse.click(node["x"], node["y"])
    page.mouse.move(5, 5)
    page.wait_for_timeout(300)
    out["out_selected"] = ev("() => awsSecurityViz.cy.elements(':selected').map(e => e.id())")
    out["grey_out_selected"] = grey(page.locator("#cy").screenshot())
    out["zoom_out_selected"] = ev("() => awsSecurityViz.cy.zoom()")
    browser.close()

print(json.dumps(out))
