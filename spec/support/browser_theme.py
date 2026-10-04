# Checks the viewer's light and dark themes in headless Chromium and prints a JSON summary: the palette each theme gives the
# graph, WCAG contrast of graph colours and chrome text, and what a switch with the toggle leaves alone.
# Run: uv run --locked --group browser python3 spec/support/browser_theme.py REPORT.html
import io
import json
import re
import sys

from PIL import Image
from playwright.sync_api import sync_playwright

report = sys.argv[1]
out = {"errors": [], "requests": [], "runs": {}}


def lum(rgb):
    def f(c):
        c /= 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(rgb[0]) + 0.7152 * f(rgb[1]) + 0.0722 * f(rgb[2])


def ratio(a, b):
    hi, lo = sorted([lum(a), lum(b)], reverse=True)
    return (hi + 0.05) / (lo + 0.05)


def rgba(text):
    text = text.strip()
    if text.startswith("#"):
        return [int(text[i:i + 2], 16) for i in (1, 3, 5)] + [1.0]
    nums = [float(x) for x in re.findall(r"[\d.]+", text)]
    return nums[:3] + [nums[3] if len(nums) > 3 else 1.0]


def over(fg, bg):
    a = fg[3]
    return [round(a * fg[i] + (1 - a) * bg[i]) for i in range(3)] + [1.0]


def graph_contrast(p):
    canvas = rgba(p["canvas"])
    vpc_bg = over(rgba(p["box-fill"])[:3] + [float(p["box-opacity"])], canvas)
    fails = []

    def check(name, fg, bg, need):
        r = ratio(rgba(fg), bg)
        if r < need:
            fails.append("%s %.2f < %s" % (name, r, need))

    for key, bg in [("text", canvas), ("muted", canvas), ("label", canvas), ("unused-text", canvas), ("risky-text", canvas), ("box-text", vpc_bg)]:
        check(key + " text", p[key], bg, 4.5)
    for fill in ("group-fill", "cidr-fill", "pl-fill", "exposed-fill", "coll-fill"):
        check("text on " + fill, p["text"], rgba(p[fill]), 4.5)
    for key in ("group-border", "cidr-border", "pl-border", "unused-border", "coll-border", "exposed-border", "box-border", "region-border",
                "ingress", "egress", "risky", "path", "accent"):
        check(key, p[key], canvas, 3)
    return fails


CONTROLS = ["#search", "#layout", "#reset", "#path-find", "#path-clear", "#path-from", "#path-port", "#theme", "#expand-all", "#collapse-all",
            "label.chip", "#details", "#details h2", "#details h3", "#legend", "#legend summary", "#legend .lg-h", "#legend .lg-note"]
CONTROL_JS = """(selectors) => {
  const parse = (t) => { const n = (t.match(/[\\d.]+/g) || []).map(Number); return [n[0], n[1], n[2], n.length > 3 ? n[3] : 1]; };
  const effective = (el) => {
    const stack = [];
    for (let e = el; e; e = e.parentElement) stack.push(parse(getComputedStyle(e).backgroundColor));
    let bg = [255, 255, 255, 1];
    for (const c of stack.reverse()) { const a = c[3]; bg = [0, 1, 2].map(i => a * c[i] + (1 - a) * bg[i]).concat([1]); }
    return bg;
  };
  return selectors.map((s) => {
    const el = document.querySelector(s);
    if (!el) return {selector: s, missing: true};
    return {selector: s, color: parse(getComputedStyle(el).color), bg: effective(el)};
  });
}"""


def chrome_contrast(page):
    fails = []
    for c in page.evaluate(CONTROL_JS, CONTROLS):
        if c.get("missing"):
            fails.append(c["selector"] + " missing")
            continue
        r = ratio(c["color"], c["bg"])
        if r < 4.5:
            fails.append("%s %.2f < 4.5" % (c["selector"], r))
    return fails


def rgb_css(hex_or_rgba):
    c = rgba(hex_or_rgba)
    return "rgb(%d,%d,%d)" % (c[0], c[1], c[2])


def corner_colour(page):
    box = page.evaluate("(() => { const r = document.getElementById('cy').getBoundingClientRect(); return {x: r.right - 24, y: r.top + 4, w: 16, h: 16}; })()")
    shot = page.screenshot(clip={"x": box["x"], "y": box["y"], "width": box["w"], "height": box["h"]})
    colours = Image.open(io.BytesIO(shot)).convert("RGB").getcolors()
    return list(max(colours)[1])


OVERLAP = """(only) => {
  const cy = awsSecurityViz.cy, c = document.getElementById('cy').getBoundingClientRect(), l = document.getElementById('legend').getBoundingClientRect();
  const box = {x1: l.left - c.left, x2: l.right - c.left, y1: l.top - c.top, y2: l.bottom - c.top};
  const set = only ? cy.nodes(only) : cy.nodes();
  return set.filter(n => { const b = n.renderedBoundingBox({includeLabels: false, includeOverlays: false});
    return b.x1 < box.x2 && b.x2 > box.x1 && b.y1 < box.y2 && b.y2 > box.y1; }).map(n => n.id());
}"""

SNAPSHOT = """() => {
  const cy = awsSecurityViz.cy;
  const pos = {};
  cy.nodes().forEach(n => { pos[n.id()] = [n.position().x, n.position().y]; });
  return {pos, zoom: cy.zoom(), pan: cy.pan(), selected: cy.elements(':selected').map(e => e.id()).sort(),
          collapsed: cy.nodes('.collapsed').map(n => n.id()).sort(), match: cy.nodes('.match').map(n => n.id()).sort(),
          search: document.getElementById('search').value, layout: awsSecurityViz.layout, renderer: awsSecurityViz.renderer,
          details: document.getElementById('details').textContent, riskyOnly: document.getElementById('risky-only').checked,
          hidden: cy.edges().filter(e => e.style('display') === 'none').map(e => e.id()).sort()};
}"""

PROBE = """(ids) => {
  const cy = awsSecurityViz.cy;
  const group = cy.getElementById('sg-0-5'), other = cy.getElementById('sg-0-6'), edge = cy.getElementById('sg-0-5-sg-0-6');
  [group, other, edge].forEach(e => e.addClass('path'));
  cy.getElementById('sg-0-7').addClass('dim');
  const s = (e, p) => e.style(p);
  const [a, b] = [cy.getElementById('sg-0-1'), cy.getElementById('sg-0-2')];
  const read = (classes) => {
    const e = cy.add({group: 'edges', data: {id: 'probe-' + classes, source: a.id(), target: b.id()}, classes: classes});
    const v = e.style('line-color');
    cy.remove(e);
    return v;
  };
  const out = {pathBorder: s(group, 'border-color'), pathEdge: s(edge, 'line-color'), dim: cy.getElementById('sg-0-7').numericStyle('opacity'),
               sg: s(cy.getElementById('sg-0-4'), 'background-color'), sgBorder: s(cy.getElementById('sg-0-4'), 'border-color'),
               cidr: s(cy.getElementById('10.0.0.0/8'), 'border-color'), internet: s(cy.getElementById('0.0.0.0/0'), 'border-color'),
               exposed: s(cy.getElementById('sg-0-0'), 'border-color'), match: s(cy.getElementById('sg-0-3'), 'border-color'),
               ingress: read('ingress'), egress: read('egress'), risky: read('ingress risky'),
               vpc: s(cy.getElementById(ids[0]), 'border-color'), collapsedVpc: s(cy.getElementById(ids[1]), 'border-color')};
  [group, other, edge, cy.getElementById('sg-0-7')].forEach(e => e.removeClass('path dim'));
  return out;
}"""


def expected(p):
    c = rgb_css
    return {"pathBorder": c(p["path"]), "pathEdge": c(p["path"]), "dim": float(p["dim"]), "sg": c(p["group-fill"]), "sgBorder": c(p["group-border"]),
            "cidr": c(p["cidr-border"]), "internet": c(p["risky"]), "exposed": c(p["exposed-border"]), "match": c(p["accent"]),
            "ingress": c(p["ingress"]), "egress": c(p["egress"]), "risky": c(p["risky"]), "vpc": c(p["box-border"]),
            "collapsedVpc": c(p["coll-border"])}


def mismatches(got, p):
    want = expected(p)
    return ["%s: %s != %s" % (k, got[k], want[k]) for k in want if (abs(got[k] - want[k]) > 0.01 if k == "dim" else got[k] != want[k])]


def run(browser, scheme, webgl):
    page = browser.new_page(viewport={"width": 1300, "height": 800}, color_scheme=scheme)
    page.on("request", lambda r: out["requests"].append(r.url))
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.on("console", lambda m: out["errors"].append(m.text) if m.type == "error" or "Content Security" in m.text else None)
    page.goto("file://" + report)
    page.wait_for_selector("canvas")
    if webgl:
        page.check("#webgl")
    page.wait_for_timeout(400)
    ids = ["vpc:eu-west-1|vpc-0", "vpc:eu-west-1|vpc-1"]
    res = {"theme": page.evaluate("awsSecurityViz.theme"), "renderer": page.evaluate("awsSecurityViz.renderer"),
           "pressed": page.get_attribute("#theme", "aria-pressed"), "palette": page.evaluate("awsSecurityViz.palette()")}
    res["graph_contrast"] = graph_contrast(res["palette"])
    # The legend sits over the canvas, so fits leave room for it: the loaded view, another layout and a search hit.
    res["legend_overlap"] = {"load": page.evaluate(OVERLAP, None)}
    page.select_option("#layout", "flow")
    res["legend_overlap"]["flow"] = page.evaluate(OVERLAP, None)
    page.select_option("#layout", "fcose")
    page.fill("#search", "svc-1-7")
    page.wait_for_timeout(200)
    res["legend_overlap"]["search"] = page.evaluate(OVERLAP, ".match")
    page.fill("#search", "")
    page.evaluate("() => { awsSecurityViz.cy.nodes().removeClass('match dim'); }")
    page.click("#reset")
    # A tall graph is fitted beside the legend, not in the strip above it.
    res["tall_fit"] = page.evaluate("""() => {
      const cy = awsSecurityViz.cy, before = {zoom: cy.zoom(), pan: Object.assign({}, cy.pan())};
      const probe = cy.add([{group: 'nodes', data: {id: 'tall-a', w: 10, h: 10}, position: {x: 0, y: 0}}, {group: 'nodes', data: {id: 'tall-b', w: 10, h: 10}, position: {x: 0, y: 1500}}]);
      awsSecurityViz.fit(probe, 30);
      const l = document.getElementById('legend').getBoundingClientRect(), c = document.getElementById('cy').getBoundingClientRect();
      const b = probe.renderedBoundingBox({includeLabels: false, includeOverlays: false});
      const strip = Math.min(c.bottom - l.top + 12, cy.height());
      const res = {zoom: cy.zoom(), stripZoom: (cy.height() - strip - 60) / 1500, clearOfLegend: b.x1 > l.right - c.left || b.y2 < l.top - c.top, onScreen: b.y1 >= 0 && b.y2 <= cy.height()};
      cy.remove(probe);
      cy.viewport(before);
      return res;
    }""")
    # Put the viewer in a state worth keeping: a selection, a match, a collapsed VPC, a search, Risky only, a moved view.
    page.evaluate("""() => { const cy = awsSecurityViz.cy; const g = cy.getElementById('sg-0-2'); g.select(); g.emit('tap'); }""")
    page.fill("#search", "svc-0-3")
    page.evaluate("() => { awsSecurityViz.cy.getElementById('vpc:eu-west-1|vpc-1').emit('dbltap'); }")
    page.wait_for_timeout(300)
    page.evaluate("() => { const cy = awsSecurityViz.cy; cy.zoom(cy.zoom() * 1.3); cy.panBy({x: 17, y: -9}); cy.getElementById('sg-0-3').addClass('match'); }")
    res["chrome_contrast"] = chrome_contrast(page)
    res["corner_before"] = corner_colour(page)
    res["probe_mismatch_before"] = mismatches(page.evaluate(PROBE, ids), res["palette"])
    before = page.evaluate(SNAPSHOT)
    page.click("#theme")
    page.wait_for_timeout(300)
    after = page.evaluate(SNAPSHOT)
    res["switched_to"] = page.evaluate("awsSecurityViz.theme")
    res["data_theme"] = page.evaluate("document.documentElement.getAttribute('data-theme')")
    res["pressed_after"] = page.get_attribute("#theme", "aria-pressed")
    res["palette_after"] = page.evaluate("awsSecurityViz.palette()")
    res["graph_contrast_after"] = graph_contrast(res["palette_after"])
    res["chrome_contrast_after"] = chrome_contrast(page)
    res["corner_after"] = corner_colour(page)
    res["canvas_after"] = rgba(res["palette_after"]["canvas"])[:3]
    if webgl:
        # A renderer switch builds a new WebGL renderer, which must also start with the current theme's background.
        page.uncheck("#webgl")
        page.wait_for_timeout(300)
        page.check("#webgl")
        page.wait_for_timeout(400)
        res["corner_after_switch"] = corner_colour(page)
        res["renderer_after_switch"] = page.evaluate("awsSecurityViz.renderer")
    res["probe_mismatch_after"] = mismatches(page.evaluate(PROBE, ids), res["palette_after"])
    res["state_kept"] = {k: before[k] == after[k] for k in before}
    res["max_moved"] = max(abs(before["pos"][k][0] - after["pos"][k][0]) + abs(before["pos"][k][1] - after["pos"][k][1]) for k in before["pos"])
    res["selection"] = before["selected"]
    page.click("#theme")
    page.wait_for_timeout(300)
    res["round_trip"] = page.evaluate("awsSecurityViz.theme") == scheme and corner_colour(page) == res["corner_before"]
    page.close()
    return res


with sync_playwright() as p:
    browser = p.chromium.launch()
    probe = browser.new_page()
    probe.goto("file://" + report)
    out["toggle"] = probe.query_selector("#theme") is not None
    probe.close()
    if not out["toggle"]:
        print(json.dumps(out))
        sys.exit(0)
    for scheme in ("light", "dark"):
        for webgl in (False, True):
            out["runs"]["%s-%s" % (scheme, "webgl" if webgl else "canvas")] = run(browser, scheme, webgl)
    # An explicit choice beats the browser's, and a browser change is followed while there is none.
    page = browser.new_page(color_scheme="light")
    page.goto("file://" + report)
    page.wait_for_selector("canvas")
    page.emulate_media(color_scheme="dark")
    page.wait_for_timeout(200)
    out["follows_browser"] = page.evaluate("awsSecurityViz.theme")
    page.click("#theme")
    page.emulate_media(color_scheme="dark")
    page.wait_for_timeout(200)
    out["keeps_choice"] = page.evaluate("awsSecurityViz.theme")
    browser.close()

for r in out["runs"].values():
    r.pop("palette", None)
    r.pop("palette_after", None)
print(json.dumps(out))
