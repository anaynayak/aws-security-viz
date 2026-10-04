# Switches a generated .html report through every layout with the layout picker and checks, in headless Chromium, that
# each picture is really drawn: every element visible, fitted in the view, no overlaps, edges and nodes on screen
# pixels, and the structure the layout promises (flow along the rules, tier rows, rings by distance). Mouse input is
# real. Prints a JSON summary.
# Run: uv run --locked --group browser python3 spec/support/browser_layouts.py REPORT.html VPC_ID
import io
import json
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

report, vpc_id = sys.argv[1:3]
LAYOUTS = ["fcose", "flow", "rings", "grid"]
out = {"requests": [], "errors": [], "console": [], "steps": {}, "button": {}}

STATE = """() => {
  const cy = awsSecurityViz.cy;
  const shown = cy.elements().filter(e => e.style('display') !== 'none');
  const box = (a, b) => a.x1 < b.x2 && b.x1 < a.x2 && a.y1 < b.y2 && b.y1 < a.y2;
  const flat = cy.nodes('.vpc, .region').some(n => n.hasClass('flat'));
  const w = cy.width(), h = cy.height();
  const outside = shown.filter(e => {
    const b = e.renderedBoundingBox({includeLabels: false, includeOverlays: false});
    return b.x1 < -1 || b.y1 < -1 || b.x2 > w + 1 || b.y2 > h + 1;
  }).map(e => e.id());
  const vpcs = cy.nodes('.vpc').toArray();
  const vpcOverlaps = [];
  vpcs.forEach((a, i) => vpcs.slice(i + 1).forEach(b => {
    if (box(a.boundingBox({includeLabels: false}), b.boundingBox({includeLabels: false}))) vpcOverlaps.push(a.id() + ' x ' + b.id());
  }));
  const leaves = cy.nodes().filter(n => !n.isParent()).toArray();
  const overlaps = [];
  leaves.forEach((a, i) => leaves.slice(i + 1).forEach(b => {
    if (a.parent().id() === b.parent().id() && box(a.boundingBox({includeLabels: false}), b.boundingBox({includeLabels: false}))) overlaps.push(a.id() + ' x ' + b.id());
  }));
  // Whatever their parents, no two groups or peers may touch (rings draw no VPC boxes, so a VPC does not separate them).
  const overlapsAll = [];
  leaves.forEach((a, i) => leaves.slice(i + 1).forEach(b => {
    if (box(a.boundingBox({includeLabels: false}), b.boundingBox({includeLabels: false}))) overlapsAll.push(a.id() + ' x ' + b.id());
  }));
  const flatParents = cy.nodes(':parent.flat');
  const flatBoxes = {
    count: flatParents.length,
    selected: flatParents.filter(n => n.selected()).length,
    labels: flatParents.map(n => n.style('label')).filter(l => l !== ''),
    overlay: flatParents.map(n => n.numericStyle('overlay-opacity')).filter(o => o !== 0),
    fill: flatParents.map(n => n.numericStyle('background-opacity')).filter(o => o !== 0),
    border: flatParents.map(n => n.numericStyle('border-width')).filter(o => o !== 0),
  };
  const lb = cy.nodes().filter(n => !n.isParent()).renderedBoundingBox({includeLabels: false, includeOverlays: false});
  const peers = cy.nodes('[kind = "group"]').filter(n => n.isOrphan());
  const peerXs = peers.map(n => n.position('x'));
  const tier = awsSecurityViz.tiers(), ring = awsSecurityViz.rings();
  const groups = cy.nodes('[kind = "group"]').filter(n => !n.isOrphan());
  // Rules between groups of the same VPC that lead to a later tier (up to 3), where the source is not left of the target.
  const tierColumns = [], tierRows = [], flowBack = [];
  cy.edges().forEach(e => {
    const a = e.source(), b = e.target();
    if (a.isOrphan() || b.isOrphan() || a.parent().id() !== b.parent().id()) return;
    if (tier[a.id()] < tier[b.id()] && tier[b.id()] <= 3 && a.position('x') >= b.position('x')) tierColumns.push(e.id());
  });
  groups.forEach(a => groups.forEach(b => {
    if (a.parent().id() === b.parent().id() && tier[a.id()] < tier[b.id()] && a.position('y') >= b.position('y')) tierRows.push(a.id() + ' > ' + b.id());
  }));
  cy.edges().forEach(e => {
    const a = e.source(), b = e.target();
    if (a.isOrphan() || b.isOrphan() || a.position('x') < b.position('x')) return;
    flowBack.push(e.id());
  });
  const ringBad = [];
  const rad = n => Math.hypot(n.position('x'), n.position('y'));
  leaves.forEach(a => leaves.forEach(b => { if (ring[a.id()] < ring[b.id()] && rad(a) > rad(b) + 1) ringBad.push(a.id() + ' > ' + b.id()); }));
  return {
    layout: awsSecurityViz.layout, renderer: awsSecurityViz.renderer, flat: flat,
    nodes: shown.nodes().length, edges: shown.edges().length,
    invisible: shown.filter(e => !e.visible()).map(e => e.id()),
    zeroEdges: shown.edges().filter(e => { const b = e.renderedBoundingBox(); return b.w === 0 && b.h === 0; }).map(e => e.id()),
    notFinite: cy.nodes().filter(n => !isFinite(n.position('x')) || !isFinite(n.position('y')) || n.width() <= 0 || n.height() <= 0).map(n => n.id()),
    outside: outside, vpcOverlaps: vpcOverlaps, overlaps: overlaps, overlapsAll: overlapsAll, flatBoxes: flatBoxes,
    usedWidth: lb.w / w, usedHeight: lb.h / h,
    peers: peers.length, peerSpread: peers.length ? Math.max(...peerXs) - Math.min(...peerXs) : 0,
    peerLeft: peers.length && groups.length ? Math.max(...peerXs) < Math.min(...groups.map(n => n.position('x'))) : true,
    tierColumns: tierColumns, tierRows: tierRows, flowBack: flowBack, ringBad: ringBad,
    publicRadius: peers.filter(n => n.id() === '0.0.0.0/0').map(rad),
  };
}"""


# Node fills of the light theme: group, CIDR, prefix list, collapsed VPC and exposed group.
FILLS = [(255, 255, 255), (232, 245, 242), (251, 241, 227), (227, 236, 249), (253, 236, 239)]


def pixels(png):
    # Clearly coloured pixels are edges (blue, red); the node fills of the light theme are counted on their own.
    img = Image.open(io.BytesIO(png)).convert("RGB")
    raw = img.tobytes()
    edge = node = 0
    for r, g, b in zip(raw[0::3], raw[1::3], raw[2::3]):
        if max(r, g, b) - min(r, g, b) > 30 and min(r, g, b) < 235:
            edge += 1
        elif any(abs(r - fr) <= 3 and abs(g - fg) <= 3 and abs(b - fb) <= 3 for fr, fg, fb in FILLS):
            node += 1
    return edge, node


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1440, "height": 900})
    page.on("request", lambda r: out["requests"].append(r.url))
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.on("console", lambda m: out["console"].append(m.type + ": " + m.text) if m.type in ("error", "warning") else None)
    page.goto("file://" + report)
    page.wait_for_selector("canvas")
    page.add_style_tag(content="#legend { visibility: hidden; }")  # the legend sits over the canvas and would count as ink
    # Fail with a message, not a timeout, when the viewer has no layout picker.
    out["picker"] = page.query_selector("#layout") is not None
    out["options"] = page.eval_on_selector_all("#layout option", "o => o.map(x => x.value)") if out["picker"] else []
    if not out["picker"]:
        browser.close()
        print(json.dumps(out))
        sys.exit(0)

    def ev(js, arg=None):
        return page.evaluate("(arg) => { const r = (" + js + ")(arg); return r && r.cy ? null : r; }", arg)

    def step(name):
        page.wait_for_timeout(400)
        s = page.evaluate(STATE)
        s["ink"], s["nodeInk"] = pixels(page.locator("#cy").screenshot())
        out["steps"][name] = s

    def point(vpc):
        # A spot on the VPC that Cytoscape attributes to it when the real mouse is there (an edge or a child may cover its centre).
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

    def positions():
        return ev("() => Object.fromEntries(awsSecurityViz.cy.nodes().map(n => [n.id(), n.position()]))")

    # Picking a layout again draws what the first load drew.
    first = positions()
    page.select_option("#layout", "flow")
    page.select_option("#layout", "fcose")
    again = positions()
    out["repick_moved"] = max(abs(first[k]["x"] - again[k]["x"]) + abs(first[k]["y"] - again[k]["y"]) for k in first)

    def collapse_with_button():
        # A group's panel closes its VPC: the way to do it where the VPC box cannot be double-clicked.
        spot = ev("""(vpc) => {
          const cy = awsSecurityViz.cy, r = document.getElementById('cy').getBoundingClientRect();
          const n = cy.getElementById(vpc).children().filter(c => { const p = c.renderedPosition(); return p.x > 20 && p.y > 20 && p.x < cy.width() - 20 && p.y < cy.height() - 20; })[0];
          const p = n.renderedPosition();
          return {x: r.left + p.x, y: r.top + p.y};
        }""", vpc_id)
        page.mouse.move(spot["x"], spot["y"])
        page.mouse.click(spot["x"], spot["y"])
        page.wait_for_timeout(200)
        buttons = page.locator("#details button")
        out["button_text"] = buttons.first.inner_text() if buttons.count() else None
        if buttons.count():
            buttons.first.click()
        page.wait_for_timeout(300)
        return ev("(id) => awsSecurityViz.cy.getElementById(id).hasClass('collapsed')", vpc_id)

    for layout in LAYOUTS:
        page.select_option("#layout", layout)
        step(layout + ":load")
        page.click("#expand-all")
        step(layout + ":expand_all")
        page.click("#collapse-all")
        step(layout + ":collapse_all")
        # A collapsed VPC opens with a real double-click, whatever the layout.
        x, y = point(vpc_id)
        page.mouse.dblclick(x, y)
        step(layout + ":dblclick_expand")
        out["steps"][layout + ":dblclick_expand"]["children"] = ev("(id) => awsSecurityViz.cy.getElementById(id).children().length", vpc_id)
        if not out["steps"][layout + ":dblclick_expand"]["flat"]:
            x, y = point(vpc_id)
            page.mouse.dblclick(x, y)
            step(layout + ":dblclick_collapse")
        if out["steps"][layout + ":dblclick_expand"]["flat"] is False:
            x, y = point(vpc_id)
            page.mouse.dblclick(x, y)
        page.wait_for_timeout(300)
        out["button"][layout] = {"collapsed": collapse_with_button(), "text": out.get("button_text")}
        page.click("#expand-all")
        page.click("#webgl")
        step(layout + ":webgl")
        page.click("#webgl")
    browser.close()

print(json.dumps(out))
