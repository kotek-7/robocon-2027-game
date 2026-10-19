"""Native mobile nickname input, keyboard-height viewport and translucent gate."""

import asyncio, pathlib
from playwright.async_api import async_playwright

OUT = pathlib.Path(__file__).resolve().parents[1] / "build/qa"


async def main():
    async with async_playwright() as pw:
        b = await pw.chromium.launch(
            headless=False,
            executable_path="/home/kotek/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome",
            args=[
                "--no-sandbox",
                "--use-gl=angle",
                "--use-angle=gl",
                "--ignore-gpu-blocklist",
            ],
        )
        p = await b.new_page(
            viewport={"width": 844, "height": 390}, has_touch=True, is_mobile=True
        )
        errors = []
        p.on("pageerror", lambda e: errors.append(str(e)))
        p.on("console", lambda m: errors.append(m.text) if m.type == "error" else None)
        await p.goto("http://127.0.0.1:8087/?qa=1")
        await p.wait_for_function("window.__arenaQA", timeout=60000)
        await p.touchscreen.tap(110, 38)
        await p.wait_for_timeout(700)
        field = p.get_by_role("textbox", name="Nickname")
        await field.fill("MangoRover")
        await p.set_viewport_size({"width": 844, "height": 210})
        await p.wait_for_timeout(800)
        rect = await field.bounding_box()
        assert rect["y"] >= 0 and rect["y"] + rect["height"] < 210, rect
        await field.press("Enter")
        await p.wait_for_function("window.__arenaQA?.nickname==='MangoRover'")
        await p.set_viewport_size({"width": 844, "height": 390})
        await p.wait_for_timeout(700)
        await p.screenshot(path=str(OUT / "profile-mobile-title.png"))
        await p.set_viewport_size({"width": 390, "height": 844})
        await p.wait_for_timeout(1200)
        assert await p.evaluate("window.__arenaQA.landscape_required")
        await p.screenshot(path=str(OUT / "field-rotate.png"))
        assert not errors, errors
        print(
            "PASS: mobile native name input, reduced keyboard viewport, Enter save, portrait field backdrop; no browser errors"
        )
        await b.close()


asyncio.run(main())
