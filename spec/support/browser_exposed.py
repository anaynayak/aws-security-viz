# Collapses and expands VPCs at run time and prints whether the VPC holding a risky ingress target is drawn as exposed.
# Run: uv run --locked --group browser python3 spec/support/browser_exposed.py REPORT.html EXPOSED_VPC_ID
import json
import sys

from playwright.sync_api import sync_playwright

report, vpc = sys.argv[1:3]
out = {"errors": []}
read = "(id) => { const n = awsSecurityViz.cy.getElementById(id); return {collapsed: n.hasClass('collapsed'), exposed: n.hasClass('exposed')}; }"
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1300, "height": 800})
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.goto("file://" + report)
    page.wait_for_selector("canvas")
    out["open"] = page.evaluate(read, vpc)
    page.click("#collapse-all")
    page.wait_for_timeout(200)
    out["collapse_all"] = page.evaluate(read, vpc)
    page.click("#expand-all")
    page.wait_for_timeout(200)
    out["expand_all"] = page.evaluate(read, vpc)
    page.evaluate("(id) => { awsSecurityViz.cy.getElementById(id).emit('dbltap'); }", vpc)
    page.wait_for_timeout(200)
    out["dblclick"] = page.evaluate(read, vpc)
    browser.close()
print(json.dumps(out))
