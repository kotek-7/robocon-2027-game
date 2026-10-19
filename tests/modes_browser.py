"""CPU handoff and two actual browser clients using the 1v1 UI."""

import asyncio, json, pathlib
from playwright.async_api import async_playwright

OUT = pathlib.Path(__file__).resolve().parents[1] / "build/qa"


async def state(p):
    return await p.evaluate("window.__arenaQA")


async def click(p, name):
    await p.bring_to_front()
    await p.wait_for_function(
        "(name)=>window.__arenaQA?.buttons.some(b=>b.text===name)",
        arg=name,
        timeout=10000,
    )
    b = next(x for x in (await state(p))["buttons"] if x["text"] == name)
    await p.mouse.click(b["x"], b["y"])
    await p.wait_for_timeout(800)


async def main():
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(
            headless=False,
            executable_path="/home/kotek/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome",
            args=[
                "--no-sandbox",
                "--use-gl=angle",
                "--use-angle=gl",
                "--ignore-gpu-blocklist",
                "--disable-background-timer-throttling",
                "--disable-renderer-backgrounding",
            ],
        )
        pages = []
        errors = []
        for _ in range(2):
            p = await browser.new_page(viewport={"width": 1280, "height": 720})
            pages.append(p)
            p.on("pageerror", lambda e: errors.append(str(e)))
            p.on(
                "console",
                lambda m: errors.append(m.text) if m.type == "error" else None,
            )
            await p.goto("http://127.0.0.1:8087/?qa=1")
            await p.wait_for_function("window.__arenaQA", timeout=30000)
        a = pages[0]
        await a.bring_to_front()
        await a.screenshot(path=str(OUT / "large-title.png"))
        await click(a, "VS CPU")
        await a.wait_for_timeout(4000)
        d = await state(a)
        assert d["state"]["robots"][1]["p"][2] < 4.5, d
        assert (
            d["state"]["robots"][0]["p"] == [-4.8, 0, 4.9]
            or abs(d["state"]["robots"][0]["p"][2] - 4.9) < 0.01
        )
        await a.keyboard.press("q")
        await a.wait_for_timeout(2000)
        d = await state(a)
        assert d["state"]["active"][0] == 1 and d["state"]["robots"][0]["p"][2] < 4
        await a.screenshot(path=str(OUT / "cpu-partner.png"))
        await a.keyboard.press("Escape")
        await click(a, "EXIT")
        for p in pages:
            await click(p, "ONLINE")
            await click(p, "AUTO MATCH")
            await p.screenshot(path=str(OUT / "online-formats.png"))
            await click(p, "1 vs 1")
        for p in pages:
            await p.wait_for_function(
                "window.__arenaQA?.mode==='online'", timeout=15000
            )
        states = [await state(p) for p in pages]
        assert [s["robot_id"] for s in states] == [-1, -1], states
        assert len({s["room"] for s in states}) == 1
        for p in pages:
            await p.bring_to_front()
            if (await state(p))["menu"]:
                await click(p, "RESUME")
            await p.keyboard.press("q")
            await p.wait_for_timeout(1400)
            s = await state(p)
            assert s["state"]["active"][s["team"]] == s["team"] * 2 + 1
            assert s["names"].count("CPU") == 2, s["names"]
            await p.keyboard.press("Escape")
            await p.wait_for_timeout(700)
            assert not (await state(p))["nameplates_visible"]
        await pages[1].screenshot(path=str(OUT / "1v1-menu.png"))
        report = {
            "cpu_partner": True,
            "switch_handoff": True,
            "two_browser_match": True,
            "online_cpu_handoff": True,
            "menu_hides_names": True,
            "errors": errors,
        }
        (OUT / "modes-browser.json").write_text(json.dumps(report, indent=2))
        print(report)
        assert not errors
        await browser.close()


asyncio.run(main())
