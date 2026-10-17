"""Type slowly through the browser input lifecycle; fill() alone misses focus theft."""
import asyncio
from playwright.async_api import async_playwright

async def click(page, name):
    await page.wait_for_function('(name)=>window.__arenaQA?.buttons.some(b=>b.text===name)', arg=name)
    button = await page.evaluate('(name)=>window.__arenaQA.buttons.find(b=>b.text===name)', name)
    await page.mouse.click(button['x'], button['y'])
    await page.wait_for_timeout(300)

async def main():
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=False, executable_path='/home/kotek/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome', args=['--no-sandbox','--use-gl=angle','--use-angle=gl','--ignore-gpu-blocklist'])
        for mobile in [False, True]:
            page = await browser.new_page(viewport={'width':844 if mobile else 1280,'height':390 if mobile else 720}, has_touch=mobile, is_mobile=mobile)
            errors=[]
            page.on('pageerror', lambda e: errors.append(str(e)))
            await page.goto('http://127.0.0.1:8087/?qa=1')
            await page.wait_for_function('window.__arenaQA', timeout=60000)
            await page.mouse.click(110,38)
            field=page.get_by_role('textbox',name='Nickname')
            await field.click()
            await field.press('ControlOrMeta+A')
            await page.keyboard.type('Pilot7',delay=160)
            await page.wait_for_timeout(400)
            assert await field.input_value()=='Pilot7'
            assert await field.evaluate('(e)=>document.activeElement===e')
            # Browser text insertion also covers non-ASCII committed IME text.
            await field.press('ControlOrMeta+A')
            await page.keyboard.insert_text('はる7')
            await field.press('Enter')
            await page.wait_for_function("window.__arenaQA.nickname==='はる7'")
            await click(page,'ONLINE');await click(page,'ROOM')
            code=page.get_by_role('textbox',name='Room code')
            await code.click()
            await page.keyboard.type('abc',delay=160)
            await code.press('Enter')
            await page.wait_for_timeout(300)
            assert await code.input_value()=='abc', (mobile,await code.input_value(),await page.evaluate('document.activeElement.outerHTML'))
            await page.keyboard.type('123',delay=160)
            assert await code.input_value()=='abc123'
            await code.press('ControlOrMeta+A');await page.keyboard.insert_text('d4e5f6')
            assert await code.input_value()=='d4e5f6'
            await click(page,'BACK')
            assert await page.locator('[data-arena-input]').count()==0
            assert not errors,errors
            await page.close()
        await browser.close()
        print('PASS: desktop/mobile slow typing, focus retention, Japanese name save, room code editing and input cleanup')

asyncio.run(main())
