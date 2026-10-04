# Drives the "can X reach Y" path query of a generated .html report with real keyboard and mouse input in headless
# Chromium and prints a JSON summary. Every query is typed into the pickers, run, inspected (model state plus
# screenshot pixels) and cleared again.
# Run: uv run --locked --group browser python3 spec/support/browser_path.py REPORT.html QUERIES_JSON [--webgl]
# QUERIES_JSON is a list of {"from": text, "to": text, "port": text}; an entry may also be {"toggle": "#ingress"}.
import io
import json
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

report, queries = sys.argv[1], json.loads(sys.argv[2])
webgl = "--webgl" in sys.argv
out = {"requests": [], "dialogs": [], "errors": [], "console": [], "queries": []}


CANVAS = [15, 23, 32]  # the dark theme's canvas; the page runs in the dark scheme (see below)


def dark(png):
    # Label text and borders are far from the canvas colour; counts how much of them is drawn at full strength. Dimmed
    # elements are close to the canvas.
    img = Image.open(io.BytesIO(png)).convert("RGB")
    raw = img.tobytes()
    return sum(1 for r, g, b in zip(raw[0::3], raw[1::3], raw[2::3]) if abs(r - CANVAS[0]) + abs(g - CANVAS[1]) + abs(b - CANVAS[2]) > 330)


def orange(png):
    # Exactly the path colour of the dark theme (#ffd23f); the match and selection colour (the orange accent) must not count.
    img = Image.open(io.BytesIO(png)).convert("RGB")
    raw = img.tobytes()
    return sum(1 for r, g, b in zip(raw[0::3], raw[1::3], raw[2::3]) if r >= 250 and 205 <= g <= 215 and 58 <= b <= 68)


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1440, "height": 900}, color_scheme="dark")
    page.on("request", lambda r: out["requests"].append(r.url))
    page.on("dialog", lambda d: (out["dialogs"].append(d.message), d.dismiss()))
    page.on("console", lambda m: out["console"].append(m.type + ": " + m.text) if m.type in ("error", "warning") else None)
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.goto("file://" + report)
    page.wait_for_selector("canvas")
    page.add_style_tag(content="#legend { visibility: hidden; }")  # the legend sits over the canvas and would count as ink
    page.wait_for_timeout(400)
    # Fail with a message, not a timeout, when the viewer has no path pickers.
    out["picker"] = page.query_selector("#path-from") is not None
    if not out["picker"]:
        browser.close()
        print(json.dumps(out))
        sys.exit(0)

    def ev(js, arg=None):
        return page.evaluate("(arg) => { const r = (" + js + ")(arg); return r && r.cy ? null : r; }", arg)

    if webgl:
        page.click("#webgl")
    out["renderer"] = ev("() => awsSecurityViz.renderer")

    def view():
        return ev("""() => {
          const cy = awsSecurityViz.cy;
          const path = cy.elements('.path');
          const nodes = cy.nodes('.path[kind = "group"]');
          const w = cy.width(), h = cy.height();
          return {
            collapsed: cy.nodes('.collapsed').map(n => n.id()).sort(),
            zoom: cy.zoom(), pan: cy.pan(),
            pathNodes: nodes.map(n => n.id()).sort(),
            pathEdges: path.edges().map(e => e.id()).sort(),
            dimmed: cy.elements('.dim').length,
            shown: cy.elements().filter(e => e.style('display') !== 'none').length,
            allVisible: nodes.every(n => { const b = n.renderedBoundingBox({includeLabels: false}); return b.x1 >= 0 && b.y1 >= 0 && b.x2 <= w && b.y2 <= h; }),
            details: document.getElementById('details').textContent,
            detailsMarkup: document.getElementById('details').querySelectorAll('img, script').length,
            pwned: window.pwned || null,
            dimTextOpacity: cy.elements('.dim').length ? cy.elements('.dim')[0].numericStyle('text-opacity') : null,
            pathCollapsed: cy.nodes('.collapsed.path').map(n => n.id()),
            pathVia: cy.nodes('.pathvia').map(n => n.id()).sort(),
            pathLabels: path.nodes().map(n => n.data('label')),
          };
        }""")

    def type_into(selector, text):
        page.click(selector, click_count=3)
        if text:
            page.keyboard.type(text)
        else:
            page.keyboard.press("Backspace")

    def point(vpc):
        # Where a real mouse reaches the VPC itself: probe with moves until Cytoscape reports the VPC under the pointer.
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

    def orange_fitted():
        # The path colour at a readable size: the view is fitted to the path for the count and put back after.
        view_before = ev("() => ({zoom: awsSecurityViz.cy.zoom(), pan: awsSecurityViz.cy.pan()})")
        ev("() => { const cy = awsSecurityViz.cy; const on = cy.elements('.path'); if (on.nonempty()) cy.fit(on, 60); return null; }")
        page.wait_for_timeout(200)
        n = orange(page.locator("#cy").screenshot())
        ev("(v) => { awsSecurityViz.cy.viewport({zoom: v.zoom, pan: v.pan}); return null; }", view_before)
        return n

    def act(a):
        if a["do"] == "search":
            type_into("#search", a["text"])
            page.keyboard.press("Enter")
        elif a["do"] == "clear_search":
            type_into("#search", "")
        elif a["do"] == "expand_all":
            page.click("#expand-all")
        elif a["do"] == "dblclick":
            x, y = point(a["vpc"])
            page.mouse.dblclick(x, y)
        page.wait_for_timeout(500)
        res = view()
        res["orange"] = orange(page.locator("#cy").screenshot())
        res["orange_fit"] = orange_fitted()
        res["dark"] = dark(page.locator("#cy").screenshot())
        return res

    out["before"] = view()
    out["before"]["dark"] = dark(page.locator("#cy").screenshot())
    out["before"]["orange"] = orange(page.locator("#cy").screenshot())
    for q in queries:
        if "toggle" in q:
            page.click(q["toggle"])
            out["queries"].append({"toggle": q["toggle"], **view()})
            continue
        type_into("#path-from", q["from"])
        page.keyboard.press("Tab")
        type_into("#path-to", q["to"])
        page.keyboard.press("Tab")
        type_into("#path-port", q.get("port", ""))
        if q.get("click"):
            page.click("#path-find")
        else:
            page.keyboard.press("Enter")
        page.wait_for_timeout(500)
        res = view()
        res["orange"] = orange(page.locator("#cy").screenshot())
        res["dark"] = dark(page.locator("#cy").screenshot())
        res["actions"] = [act(a) for a in q.get("actions", [])]
        if q.get("tap_background"):
            page.mouse.click(5, 200)   # the left edge of the canvas is empty
            page.wait_for_timeout(100)
            res["after_background_tap"] = view()
        if not q.get("keep"):
            page.click("#path-clear")
            page.wait_for_timeout(300)
            after = view()
            after["orange"] = orange(page.locator("#cy").screenshot())
            after["inputs"] = ev("() => ['path-from', 'path-to', 'path-port'].map(id => document.getElementById(id).value)")
            res["cleared"] = after
        out["queries"].append(res)
    browser.close()

print(json.dumps(out))
