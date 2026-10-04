# Drives a generated .html report through the WebGL renderer switch in headless Chromium and prints a JSON summary.
# Run: uv run --with playwright python spec/support/browser_webgl.py REPORT.html [--no-webgl] [--expand-all] [--screenshot FILE]
import json
import sys

from playwright.sync_api import sync_playwright

args = sys.argv[1:]
report = args[0]
no_webgl = "--no-webgl" in args
expand_all = "--expand-all" in args
shot = args[args.index("--screenshot") + 1] if "--screenshot" in args else None
out = {"requests": [], "dialogs": [], "errors": [], "console": []}

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.on("request", lambda r: out["requests"].append(r.url))
    page.on("dialog", lambda d: (out["dialogs"].append(d.message), d.dismiss()))
    page.on("console", lambda m: out["console"].append(m.type + ": " + m.text) if m.type in ("error", "warning") else None)
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    if no_webgl:
        # What a browser without WebGL does: no context can be created.
        page.add_init_script("""
          const original = HTMLCanvasElement.prototype.getContext;
          HTMLCanvasElement.prototype.getContext = function (kind, ...rest) {
            return /webgl/.test(kind) ? null : original.call(this, kind, ...rest);
          };
        """)
    page.goto("file://" + report)
    page.wait_for_selector("canvas")

    def ev(js):
        return page.evaluate("(() => { const r = " + js + "; return r && r.cy ? null : r; })()")

    def state():
        return {
            "renderer": ev("awsSecurityViz.renderer"),
            "checked": ev("document.getElementById('webgl').checked"),
            "disabled": ev("document.getElementById('webgl').disabled"),
            "elements": ev("awsSecurityViz.cy.elements().length"),
            "nodes": ev("awsSecurityViz.cy.nodes().length"),
            "canvases": ev("awsSecurityViz.cy.container().querySelectorAll('canvas').length"),
        }

    out["threshold"] = ev("awsSecurityViz.webglThreshold")
    out["initial"] = state()
    if expand_all:
        page.click("#expand-all")
        out["after_expand_all"] = state()
    if not no_webgl:
        out["pre_toggle_positions"] = ev("awsSecurityViz.cy.nodes().map(n => [n.id(), Math.round(n.position().x), Math.round(n.position().y)]).slice(0, 5)")
        page.click("#webgl")
        out["toggled_on"] = state()
        out["post_toggle_positions"] = ev("awsSecurityViz.cy.nodes().map(n => [n.id(), Math.round(n.position().x), Math.round(n.position().y)]).slice(0, 5)")
        # Interactions still work after the switch.
        ev("awsSecurityViz.cy.nodes('[kind = \"group\"]')[0].emit('tap')")
        out["details_after_switch"] = ev("document.getElementById('details').textContent")
        page.click("#ingress")
        out["ingress_hidden"] = ev("awsSecurityViz.cy.edges('.ingress').every(e => e.style('display') === 'none')")
        page.click("#ingress")
        if shot:
            page.screenshot(path=shot)
        page.click("#webgl")
        out["toggled_off"] = state()
    elif shot:
        page.screenshot(path=shot)
    # A click on a disabled box does nothing; the viewer keeps working.
    out["final"] = state()
    browser.close()

print(json.dumps(out))
