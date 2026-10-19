"""Firefox smoke check on the desktop display."""

import asyncio, json, pathlib
from playwright.async_api import async_playwright

OUT = pathlib.Path(__file__).resolve().parents[1] / "build/qa"


async def main():
    async with async_playwright() as pw:
        browser = await pw.firefox.launch(
            headless=False,
            firefox_user_prefs={
                "webgl.force-enabled": True,
                "webgl.disabled": False,
                "gfx.webrender.all": True,
                "layers.acceleration.force-enabled": True,
            },
        )
        p = await browser.new_page(viewport={"width": 1280, "height": 720})
        errors = []
        p.on("pageerror", lambda e: errors.append(str(e)))
        await p.goto("http://127.0.0.1:8087/?qa=1")
        await p.wait_for_function("window.__arenaQA", timeout=30000)
        await p.bring_to_front()
        btn = await p.evaluate("window.__arenaQA.buttons.find(b=>b.text==='FREE')")
        await p.mouse.click(btn["x"], btn["y"])
        await p.wait_for_timeout(1000)
        before = await p.evaluate("window.__arenaQA")
        await p.keyboard.down("w")
        await p.wait_for_timeout(1500)
        await p.keyboard.up("w")
        await p.wait_for_timeout(800)
        after = await p.evaluate("window.__arenaQA")
        assert (
            after["state"]["robots"][0]["p"][2]
            < before["state"]["robots"][0]["p"][2] - 0.2
        )
        await p.keyboard.press("q")
        await p.wait_for_timeout(700)
        assert await p.evaluate("window.__arenaQA.state.active[0]") == 1
        await p.screenshot(path=str(OUT / "firefox.png"))
        report = {
            "browser": browser.version,
            "display": ":0",
            "movement": True,
            "switch": True,
            "fps": after["fps"],
            "errors": errors,
        }
        (OUT / "firefox.json").write_text(json.dumps(report, indent=2))
        print(report)
        assert not errors
        await browser.close()


asyncio.run(main())
