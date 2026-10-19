"""Virtual browser Gamepad API input; this does not certify a physical controller."""

import asyncio, json, pathlib
from playwright.async_api import async_playwright

OUT = pathlib.Path(__file__).resolve().parents[1] / "build/qa"


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
            ],
        )
        p = await browser.new_page(viewport={"width": 1280, "height": 720})
        await p.add_init_script(
            """window.testAudioContexts=[];window.AudioContext=new Proxy(window.AudioContext,{construct(T,args){const c=new T(...args);window.testAudioContexts.push(c);return c}});"""
        )
        await p.add_init_script(
            """window.testPad={id:'Test standard controller',index:0,connected:true,mapping:'standard',timestamp:0,axes:[0,0,0,0],buttons:Array.from({length:17},()=>({pressed:false,touched:false,value:0}))};navigator.getGamepads=()=>[window.testPad];"""
        )
        await p.goto("http://127.0.0.1:8087/?qa=1")
        await p.wait_for_function("window.__arenaQA", timeout=30000)
        await p.bring_to_front()
        b = await p.evaluate("window.__arenaQA.buttons.find(b=>b.text==='FREE')")
        await p.mouse.click(b["x"], b["y"])
        await p.wait_for_timeout(800)
        await p.evaluate(
            "(()=>{const e=new Event('gamepadconnected');Object.defineProperty(e,'gamepad',{value:window.testPad});window.dispatchEvent(e);})()"
        )
        before = await p.evaluate("window.__arenaQA.state.robots[0].p[2]")
        await p.evaluate("window.testPad.axes[1]=-1")
        await p.wait_for_timeout(1500)
        await p.evaluate("window.testPad.axes[1]=0")
        await p.wait_for_timeout(700)
        after = await p.evaluate("window.__arenaQA.state.robots[0].p[2]")
        assert after < before - 0.2
        await p.evaluate(
            "window.testPad.buttons[3]={pressed:true,touched:true,value:1}"
        )
        await p.wait_for_timeout(150)
        await p.evaluate(
            "window.testPad.buttons[3]={pressed:false,touched:false,value:0}"
        )
        await p.wait_for_timeout(700)
        assert await p.evaluate("window.__arenaQA.state.active[0]") == 1
        await p.screenshot(path=str(OUT / "gamepad.png"))
        audio = await p.evaluate("window.testAudioContexts.map(c=>c.state)")
        assert "running" in audio, audio
        report = {
            "virtual_gamepad_movement": True,
            "virtual_gamepad_switch": True,
            "audio_contexts": audio,
            "physical_controller_tested": False,
        }
        (OUT / "gamepad.json").write_text(json.dumps(report, indent=2))
        print(report)
        await browser.close()


asyncio.run(main())
