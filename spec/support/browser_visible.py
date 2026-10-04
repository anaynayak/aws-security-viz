# Checks, in headless Chromium, that every element the viewer shows is really drawn after each way of changing
# the graph, and prints a JSON summary.
# Run: uv run --locked --group browser python3 spec/support/browser_visible.py REPORT.html VPC_ID
import io
import json
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

report, vpc_id = sys.argv[1:3]
out = {"errors": [], "console": [], "steps": {}}

STATE = """() => {
  const cy = awsSecurityViz.cy;
  const shown = cy.elements().filter(e => e.style('display') !== 'none');
  const edges = shown.edges();
  const box = (a, b) => a.x1 < b.x2 && b.x1 < a.x2 && a.y1 < b.y2 && b.y1 < a.y2;
  const sib = cy.nodes('.vpc').toArray();
  const vpcOverlaps = [];
  sib.forEach((a, i) => sib.slice(i + 1).forEach(b => {
    if (box(a.boundingBox({includeLabels: false}), b.boundingBox({includeLabels: false}))) vpcOverlaps.push(a.id() + ' x ' + b.id());
  }));
  const leaves = cy.nodes('[kind = "group"]').toArray();
  const groupOverlaps = [];
  leaves.forEach((a, i) => leaves.slice(i + 1).forEach(b => {
    if (a.parent().id() === b.parent().id() && box(a.boundingBox({includeLabels: false}), b.boundingBox({includeLabels: false}))) groupOverlaps.push(a.id() + ' x ' + b.id());
  }));
  const peerInVpc = cy.nodes(':orphan').filter(n => !n.isParent() && !n.is('.vpc, .region')).filter(n =>
    sib.some(v => box(n.boundingBox({includeLabels: false}), v.boundingBox({includeLabels: false})))).map(n => n.id());
  return {
    renderer: awsSecurityViz.renderer,
    nodes: shown.nodes().length,
    edges: edges.length,
    invisible: shown.filter(e => !e.visible()).map(e => e.id()),
    zeroEdges: edges.filter(e => { const b = e.renderedBoundingBox(); return b.w === 0 && b.h === 0; }).map(e => e.id()),
    vpcOverlaps: vpcOverlaps,
    peerInVpc: peerInVpc,
    groupOverlaps: groupOverlaps,
  };
}"""

def ink(png):
    # Count clearly coloured pixels. Nodes are pale blue and text is grey, so what is left is edges (blue, red,
    # magenta): proof they reached the screen, not just the model. Thin, zoomed-out edges are anti-aliased, so
    # the test is saturation rather than an exact colour.
    img = Image.open(io.BytesIO(png)).convert("RGB")
    raw = img.tobytes()
    n = 0
    for r, g, b in zip(raw[0::3], raw[1::3], raw[2::3]):
        if max(r, g, b) - min(r, g, b) > 30 and min(r, g, b) < 235:
            n += 1
    return n


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1440, "height": 900})
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.on("console", lambda m: out["console"].append(m.type + ": " + m.text) if m.type in ("error", "warning") else None)
    page.goto("file://" + report)
    page.wait_for_selector("canvas")

    def ev(js, arg=None):
        return page.evaluate("(arg) => { const r = (" + js + ")(arg); return r && r.cy ? null : r; }", arg)

    def step(name):
        page.click("#reset")
        page.wait_for_timeout(400)
        s = page.evaluate(STATE)
        s["ink"] = ink(page.locator("#cy").screenshot())
        out["steps"][name] = s

    def point(vpc, expanded):
        # Where to double-click a VPC with the real mouse: a spot inside it that Cytoscape attributes to the VPC when
        # the pointer moves there (an edge or a child may cover its centre).
        ev("""() => { const cy = awsSecurityViz.cy; if (window.__probe !== cy) { window.__probe = cy; cy.on('mousemove', e => { window.__over = e.target === cy ? null : e.target.id(); }); } return null; }""")
        box = ev("""(id) => {
          const cy = awsSecurityViz.cy, r = document.getElementById('cy').getBoundingClientRect();
          const b = cy.getElementById(id).renderedBoundingBox({includeLabels: false, includeOverlays: false});
          return {x: r.left + b.x1, y: r.top + b.y1, w: b.w, h: b.h};
        }""", vpc)
        coarse = (0.1, 0.25, 0.5, 0.75, 0.9)
        fine = tuple(i / 20 for i in range(1, 20))
        for fy in (0.02, 0.05) + coarse + fine:
            for fx in coarse + fine:
                x, y = box["x"] + box["w"] * fx, box["y"] + box["h"] * fy
                page.mouse.move(x - 1, y)
                page.mouse.move(x, y)
                page.wait_for_timeout(30)
                if ev("() => window.__over") == vpc:
                    return x, y
        raise SystemExit("no spot on " + vpc + " reaches the VPC")

    step("load")
    page.click("#expand-all")
    step("expand_all")
    page.click("#collapse-all")
    step("collapse_all")

    def collapsed():
        return ev("(id) => awsSecurityViz.cy.getElementById(id).hasClass('collapsed')", vpc_id)

    def dblclick(name):
        # A real mouse double-click on the VPC, flipping it between collapsed and expanded.
        page.click("#reset")
        was = collapsed()
        x, y = point(vpc_id, not was)
        page.mouse.dblclick(x, y)
        step(name)
        out["toggled_" + name] = [was, collapsed()]

    dblclick("dblclick_1")
    out["children_" + "dblclick_1"] = ev("(id) => awsSecurityViz.cy.getElementById(id).children().length", vpc_id)
    dblclick("dblclick_2")
    out["children_" + "dblclick_2"] = ev("(id) => awsSecurityViz.cy.getElementById(id).children().length", vpc_id)

    page.click("#expand-all")
    page.click("#reset")
    page.click("#webgl")
    step("webgl_on")
    page.click("#collapse-all")
    dblclick("webgl_dblclick")
    page.click("#webgl")
    step("webgl_off")
    browser.close()

print(json.dumps(out))
