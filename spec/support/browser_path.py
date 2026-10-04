# Drives the "can X reach Y" path query of a generated .html report with real keyboard and mouse input in headless
# Chromium and prints a JSON summary. Every query is typed into the pickers, run, inspected (model state plus
# screenshot pixels) and cleared again.
# Run: uv run --with playwright --with pillow python spec/support/browser_path.py REPORT.html QUERIES_JSON [--webgl]
# QUERIES_JSON is a list of {"from": text, "to": text, "port": text}; an entry may also be {"toggle": "#ingress"}.
import io
import json
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

report, queries = sys.argv[1], json.loads(sys.argv[2])
webgl = "--webgl" in sys.argv
out = {"requests": [], "dialogs": [], "errors": [], "console": [], "queries": []}


def orange(png):
    # The path colour (#ff8c00) is used by nothing else, so counting it proves the highlight reached the screen.
    img = Image.open(io.BytesIO(png)).convert("RGB")
    raw = img.tobytes()
    return sum(1 for r, g, b in zip(raw[0::3], raw[1::3], raw[2::3]) if r > 235 and 110 < g < 165 and b < 40)


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1440, "height": 900})
    page.on("request", lambda r: out["requests"].append(r.url))
    page.on("dialog", lambda d: (out["dialogs"].append(d.message), d.dismiss()))
    page.on("console", lambda m: out["console"].append(m.type + ": " + m.text) if m.type in ("error", "warning") else None)
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.goto("file://" + report)
    page.wait_for_selector("canvas")
    page.wait_for_timeout(400)

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
          };
        }""")

    def type_into(selector, text):
        page.click(selector, click_count=3)
        if text:
            page.keyboard.type(text)
        else:
            page.keyboard.press("Backspace")

    out["before"] = view()
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
