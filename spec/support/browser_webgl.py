# Drives a generated .html report through the WebGL renderer switch in headless Chromium and prints a JSON summary.
# Run: uv run --with playwright python spec/support/browser_webgl.py REPORT.html [--no-webgl] [--expand-all] [--churn] [--webgl-throws] [--lose-context] [--screenshot FILE]
import json
import sys

from playwright.sync_api import sync_playwright

args = sys.argv[1:]
report = args[0]
no_webgl = "--no-webgl" in args
expand_all = "--expand-all" in args
churn = "--churn" in args
throws = "--webgl-throws" in args
lose = "--lose-context" in args
shot = args[args.index("--screenshot") + 1] if "--screenshot" in args else None
out = {"requests": [], "dialogs": [], "errors": [], "console": []}

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.on("request", lambda r: out["requests"].append(r.url))
    page.on("dialog", lambda d: (out["dialogs"].append(d.message), d.dismiss()))
    page.on("console", lambda m: out["console"].append(m.type + ": " + m.text) if m.type in ("error", "warning") else None)
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    # Remember every WebGL context the page creates, to see which are still alive.
    page.add_init_script("""
      window.__contexts = [];
      const track = HTMLCanvasElement.prototype.getContext;
      HTMLCanvasElement.prototype.getContext = function (kind, ...rest) {
        const gl = track.call(this, kind, ...rest);
        if (gl && kind === "webgl2" && !window.__contexts.includes(gl)) window.__contexts.push(gl);
        return gl;
      };
    """)
    if no_webgl:
        # What a browser without WebGL does: no context can be created.
        page.add_init_script("""
          const original = HTMLCanvasElement.prototype.getContext;
          HTMLCanvasElement.prototype.getContext = function (kind, ...rest) {
            return /webgl/.test(kind) ? null : original.call(this, kind, ...rest);
          };
        """)
    if throws:
        # A cytoscape whose WebGL renderer fails halfway through creation.
        page.add_init_script("""
          let real;
          Object.defineProperty(window, "cytoscape", {
            configurable: true,
            get() { return real; },
            set(v) {
              const wrapped = function (opts, ...rest) {
                if (opts && opts.webgl) { opts.container.appendChild(document.createElement("canvas")); throw new Error("webgl init failed"); }
                return v(opts, ...rest);
              };
              Object.assign(wrapped, v);
              real = wrapped;
            },
          });
        """)
    page.goto("file://" + report)
    page.wait_for_selector("canvas")

    def ev(js):
        return page.evaluate("(() => { const r = " + js + "; return r && r.cy ? null : r; })()")

    def finish():
        browser.close()
        print(json.dumps(out))
        sys.exit(0)

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
    if throws:
        page.click("#webgl")
        out["after_throw"] = state()
        out["stray_canvases"] = ev("document.querySelectorAll('#cy canvas').length")
        finish()
    elif not no_webgl:
        view = "(() => { const cy = awsSecurityViz.cy; return {zoom: cy.zoom(), pan: cy.pan(), positions: cy.nodes().map(n => [n.id(), n.position().x, n.position().y])}; })()"
        out["pre_toggle"] = ev(view)
        page.click("#webgl")
        out["toggled_on"] = state()
        out["post_toggle"] = ev(view)
        if lose:
            ev("(() => { const c = document.querySelector('#cy canvas[data-id=\"layer3-webgl\"]') || [...document.querySelectorAll('#cy canvas')].find(c => c.getContext('webgl2')); c.getContext('webgl2').getExtension('WEBGL_lose_context').loseContext(); })()")
            page.wait_for_timeout(500)
            out["after_loss"] = state()
            finish()
        if churn:
            for _ in range(20):
                page.click("#webgl")
                page.click("#webgl")
            out["after_churn"] = state()
            out["contexts_created"] = ev("window.__contexts.length")
            out["contexts_alive"] = ev("window.__contexts.filter(gl => !gl.isContextLost()).length")
            finish()
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
