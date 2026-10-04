# Drives a generated .html report with collapsible VPCs in headless Chromium and prints a JSON summary.
# Run: uv run --with playwright python spec/support/browser_collapse.py REPORT.html VPC_ID GROUP_LABEL
import json
import sys

from playwright.sync_api import sync_playwright

report, vpc_id, group_label = sys.argv[1:4]
out = {"requests": [], "dialogs": [], "errors": [], "console": []}

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.on("request", lambda r: out["requests"].append(r.url))
    page.on("dialog", lambda d: (out["dialogs"].append(d.message), d.dismiss()))
    page.on("console", lambda m: out["console"].append(m.type + ": " + m.text) if m.type in ("error", "warning") else None)
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.goto("file://" + report)
    page.wait_for_selector("canvas")

    def ev(js):
        # Playwright serialises the returned value, so never hand it a Cytoscape collection (emit returns one).
        return page.evaluate("(() => { const r = " + js + "; return r && r.length !== undefined && typeof r !== 'string' && r.cy ? null : r; })()")

    def snapshot():
        return ev("""(() => {
          const cy = awsSecurityViz.cy;
          return {
            groups: cy.nodes('[kind = "group"]').length,
            collapsed: cy.nodes('.collapsed').map(n => n.id()),
            vpcs: cy.nodes('.vpc').length,
            meta: cy.edges('.meta').length,
            labels: cy.nodes('.collapsed').map(n => n.data('label')),
          };
        })()""")

    out["threshold"] = ev("awsSecurityViz.collapseThreshold")
    out["initial"] = snapshot()
    out["meta_edge_label"] = ev("awsSecurityViz.cy.edges('.meta')[0] ? awsSecurityViz.cy.edges('.meta')[0].data('label') : null")
    out["meta_risky"] = ev("awsSecurityViz.cy.edges('.meta.risky').length")
    out["overlaps"] = ev("""(() => {
      const nodes = awsSecurityViz.cy.nodes('.collapsed').toArray();
      const bad = [];
      nodes.forEach((a, i) => nodes.slice(i + 1).forEach(b => {
        const x = a.boundingBox(), y = b.boundingBox();
        if (x.x1 < y.x2 && y.x1 < x.x2 && x.y1 < y.y2 && y.y1 < x.y2) bad.push([a.id(), b.id()]);
      }));
      return bad;
    })()""")

    def tap(id):
        ev("awsSecurityViz.cy.getElementById(%s).emit('tap')" % json.dumps(id))
        return ev("document.getElementById('details').textContent")

    out["collapsed_details"] = tap(vpc_id)
    out["internal_risky_details"] = tap("vpc:eu-west-1|vpc-5")
    meta_id = ev("awsSecurityViz.cy.edges('.meta')[0].id()")
    out["meta_details"] = tap(meta_id)
    out["into_vpc_details"] = tap("meta:vpc:eu-west-1|vpc-2>" + vpc_id + "|ingress")
    out["meta_risky_width"] = ev("awsSecurityViz.cy.edges('.meta.risky')[0].numericStyle('width')")
    peer_meta = "meta:0.0.0.0/0>vpc:eu-west-1|vpc-0|ingress"
    out["peer_meta_label"] = ev("awsSecurityViz.cy.getElementById(%s).data('label')" % json.dumps(peer_meta))
    page.click("#risky-only")
    out["risky_only_label"] = ev("awsSecurityViz.cy.getElementById(%s).data('label')" % json.dumps(peer_meta))
    out["risky_only_visible"] = ev("awsSecurityViz.cy.edges().filter(e => e.style('display') !== 'none').map(e => e.id())")
    out["risky_only_details"] = tap(peer_meta)
    page.click("#risky-only")

    # Double-click one VPC: only its groups get laid out; everything else stays put.
    before = ev("Object.fromEntries(awsSecurityViz.cy.nodes('.collapsed').map(n => [n.id(), n.position()]))")
    ev("awsSecurityViz.cy.getElementById(%s).emit('dbltap')" % json.dumps(vpc_id))
    out["after_expand"] = snapshot()
    after = ev("Object.fromEntries(awsSecurityViz.cy.nodes('.collapsed').map(n => [n.id(), n.position()]))")
    out["others_moved"] = [k for k in after if before[k] != after[k]]
    out["expanded_children"] = ev("awsSecurityViz.cy.getElementById(%s).children().length" % json.dumps(vpc_id))
    out["expanded_details"] = tap(vpc_id)
    out["group_details"] = tap(ev("awsSecurityViz.cy.getElementById(%s).children()[0].id()" % json.dumps(vpc_id)))
    ev("awsSecurityViz.cy.getElementById(%s).emit('dbltap')" % json.dumps(vpc_id))
    out["after_recollapse"] = snapshot()
    out["label_after_expand"] = None
    ev("awsSecurityViz.cy.getElementById(%s).emit('dbltap')" % json.dumps(vpc_id))
    out["label_after_expand"] = ev("awsSecurityViz.cy.getElementById(%s).data('label')" % json.dumps(vpc_id))
    ev("awsSecurityViz.cy.getElementById(%s).emit('dbltap')" % json.dumps(vpc_id))
    out["label_after_recollapse"] = ev("awsSecurityViz.cy.getElementById(%s).data('label')" % json.dumps(vpc_id))

    # Toggles apply to merged edges.
    page.click("#ingress")
    out["ingress_hidden"] = ev("awsSecurityViz.cy.edges('.meta.ingress').every(e => e.style('display') === 'none')")
    page.click("#ingress")

    # A broad query does not open anything until confirmed with Enter, and clearing it restores the view.
    page.fill("#search", "app")
    out["broad_search_collapsed"] = len(ev("awsSecurityViz.cy.nodes('.collapsed').map(n => n.id())"))
    page.press("#search", "Enter")
    out["enter_search_collapsed"] = len(ev("awsSecurityViz.cy.nodes('.collapsed').map(n => n.id())"))
    page.fill("#search", "")
    out["cleared_search_collapsed"] = len(ev("awsSecurityViz.cy.nodes('.collapsed').map(n => n.id())"))

    # Search reaches into a collapsed VPC and expands it.
    page.fill("#search", group_label)
    out["search_matches"] = ev("awsSecurityViz.cy.nodes('.match').map(n => n.id())")
    out["search_vpc_collapsed"] = ev("awsSecurityViz.cy.getElementById(%s).hasClass('collapsed')" % json.dumps(vpc_id))
    page.fill("#search", "")

    page.click("#collapse-all")
    ev("(window.layouts = 0, awsSecurityViz.cy.on('layoutstart', () => window.layouts++), 0)")
    page.click("#expand-all")
    out["expand_all_layouts"] = ev("window.layouts")
    out["all_expanded"] = snapshot()
    out["expanded_overlaps"] = ev("""(() => {
      const nodes = awsSecurityViz.cy.nodes('.vpc').toArray();
      const bad = [];
      nodes.forEach((a, i) => nodes.slice(i + 1).forEach(b => {
        if (a.parent().id() !== b.parent().id()) return;
        const x = a.boundingBox(), y = b.boundingBox();
        if (x.x1 < y.x2 && y.x1 < x.x2 && x.y1 < y.y2 && y.y1 < x.y2) bad.push([a.id(), b.id()]);
      }));
      return bad;
    })()""")
    page.click("#collapse-all")
    out["all_collapsed"] = snapshot()
    browser.close()

print(json.dumps(out))
