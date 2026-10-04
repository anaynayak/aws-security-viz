# Opens a VPC with a double-click on its collapsed node in each layout and prints what the VPC's details panel offers.
# Run: uv run --locked --group browser python3 spec/support/browser_vpc_panel.py REPORT.html VPC_ID
import json
import sys

from playwright.sync_api import sync_playwright

report, vpc_id = sys.argv[1:3]
out = {"errors": [], "layouts": {}}

with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1440, "height": 900})
    page.on("pageerror", lambda e: out["errors"].append(str(e)))
    page.goto("file://" + report)
    page.wait_for_selector("canvas")
    for layout in ("fcose", "flow", "rings", "grid"):
        page.select_option("#layout", layout)
        page.click("#collapse-all")
        page.evaluate("(id) => { awsSecurityViz.cy.getElementById(id).emit('dbltap'); }", vpc_id)
        page.wait_for_timeout(200)
        page.evaluate("(id) => { awsSecurityViz.cy.getElementById(id).emit('tap'); }", vpc_id)
        text = page.inner_text("#details")
        buttons = page.evaluate("Array.from(document.querySelectorAll('#details button')).map(b => b.textContent)")
        step = {"details": text, "buttons": buttons, "collapsed_after": None}
        if buttons:
            page.click("#details button")
            page.wait_for_timeout(200)
            step["collapsed_after"] = page.evaluate("(id) => awsSecurityViz.cy.getElementById(id).hasClass('collapsed')", vpc_id)
        out["layouts"][layout] = step
    browser.close()
print(json.dumps(out))
