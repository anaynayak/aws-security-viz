# Checks, in headless Chromium with real mouse and keyboard input, that switching layout keeps what the user set up:
# collapse state, the selected node and the details panel, search hits, the Ingress/Egress/Risky toggles and a path
# query, on the canvas and the WebGL renderer. Prints a JSON summary.
# Run: uv run --locked --group browser python3 spec/support/browser_layout_state.py REPORT.html SEARCH CLICK_ID FROM TO
import io
import json
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

report, search, click_id, path_from, path_to = sys.argv[1:6]
LAYOUTS = ["flow", "rings", "grid", "fcose"]
out = {"errors": [], "console": [], "runs": {}}

SNAPSHOT = """() => {
  const cy = awsSecurityViz.cy;
  const ids = els => els.map(e => e.id()).sort();
  const w = cy.width(), h = cy.height();
  const inView = els => els.every(n => { const b = n.renderedBoundingBox({includeLabels: false}); return b.x1 >= 0 && b.y1 >= 0 && b.x2 <= w && b.y2 <= h; });
  return {
    layout: awsSecurityViz.layout, renderer: awsSecurityViz.renderer,
    collapsed: ids(cy.nodes('.collapsed')),
    selected: ids(cy.elements(':selected')),
    matches: ids(cy.nodes('.match')),
    hidden: ids(cy.edges().filter(e => e.style('display') === 'none')),
    path: ids(cy.elements('.path')),
    dimmed: cy.elements('.dim').length,
    details: document.getElementById('details').textContent,
    search: document.getElementById('search').value,
    toggles: ['ingress', 'egress', 'risky-only'].map(id => document.getElementById(id).checked),
    pathInView: inView(cy.nodes('.path[kind = "group"]')),
    selectedInView: inView(cy.elements(':selected').nodes()),
    nodes: cy.nodes().length,
    notFinite: cy.nodes().filter(n => !isFinite(n.position('x')) || n.width() <= 0).length,
  };
}"""


def orange(png):
    # Exactly the path colour of the dark theme (#ffd23f); the match and selection colour (the orange accent) must not count.
    img = Image.open(io.BytesIO(png)).convert("RGB")
    raw = img.tobytes()
    return sum(1 for r, g, b in zip(raw[0::3], raw[1::3], raw[2::3]) if r >= 250 and 205 <= g <= 215 and 58 <= b <= 68)


with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1440, "height": 900}, color_scheme="dark")
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.on("console", lambda m: out["console"].append(m.type + ": " + m.text) if m.type in ("error", "warning") else None)
    page.goto("file://" + report)
    page.wait_for_selector("canvas")
    page.add_style_tag(content="#legend { visibility: hidden; }")  # the legend sits over the canvas and would count as ink
    out["picker"] = page.query_selector("#layout") is not None
    if not out["picker"]:
        browser.close()
        print(json.dumps(out))
        sys.exit(0)

    def ev(js, arg=None):
        return page.evaluate("(arg) => { const r = (" + js + ")(arg); return r && r.cy ? null : r; }", arg)

    def snap():
        page.wait_for_timeout(300)
        s = page.evaluate(SNAPSHOT)
        s["orange"] = orange(page.locator("#cy").screenshot())
        # The path colour at a readable size: fitted to the path for the count, the view put back after.
        view = ev("() => ({zoom: awsSecurityViz.cy.zoom(), pan: awsSecurityViz.cy.pan()})")
        ev("() => { const cy = awsSecurityViz.cy; const on = cy.elements('.path'); if (on.nonempty()) cy.fit(on, 60); return null; }")
        page.wait_for_timeout(200)
        s["orange_fit"] = orange(page.locator("#cy").screenshot())
        ev("(v) => { awsSecurityViz.cy.viewport({zoom: v.zoom, pan: v.pan}); return null; }", view)
        return s

    def type_into(selector, text):
        page.click(selector, click_count=3)
        if text:
            page.keyboard.type(text)
        else:
            page.keyboard.press("Backspace")

    def click_node(node_id):
        x, y = ev("""(id) => { const r = document.getElementById('cy').getBoundingClientRect(), p = awsSecurityViz.cy.getElementById(id).renderedPosition(); return [r.left + p.x, r.top + p.y]; }""", node_id)
        page.mouse.move(x, y)
        page.mouse.click(x, y)

    def cycle(name):
        runs = {"start": snap()}
        for layout in LAYOUTS:
            page.select_option("#layout", layout)
            runs[layout] = snap()
        out["runs"][name] = runs

    # Search, select, toggle.
    type_into("#search", search)
    page.keyboard.press("Enter")
    page.wait_for_timeout(300)
    click_node(click_id)
    page.click("#ingress")
    cycle("search_select_toggle")
    page.click("#webgl")
    cycle("search_select_toggle_webgl")
    page.click("#webgl")
    page.click("#ingress")
    type_into("#search", "")
    page.wait_for_timeout(300)
    page.click("#reset")

    # A path query.
    type_into("#path-from", path_from)
    page.keyboard.press("Tab")
    type_into("#path-to", path_to)
    page.keyboard.press("Tab")
    page.keyboard.press("Enter")
    page.wait_for_timeout(400)
    cycle("path")
    page.click("#path-clear")
    out["after_clear"] = snap()
    browser.close()

print(json.dumps(out))
