"""Real input regression: retry lock denial, TR stairs, BR ramp and title."""
import asyncio,json,pathlib,math
from playwright.async_api import async_playwright
OUT=pathlib.Path(__file__).resolve().parents[1]/'build/qa'
async def state(p):return await p.evaluate('window.__arenaQA')
async def menu(p,name):
 await p.wait_for_function('(name)=>window.__arenaQA?.buttons.some(b=>b.text===name)',arg=name,timeout=10000)
 b=next(b for b in (await state(p))['buttons'] if b['text']==name)
 await p.mouse.click(b['x'],b['y']);await p.wait_for_timeout(800)
async def drive(p,key,ms):
 await p.keyboard.down(key);await p.wait_for_timeout(ms);await p.keyboard.up(key);await p.wait_for_timeout(650)
async def main():
 async with async_playwright() as pw:
  b=await pw.chromium.launch(headless=False,executable_path='/home/kotek/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome',args=['--no-sandbox','--use-gl=angle','--use-angle=gl','--ignore-gpu-blocklist'])
  p=await b.new_page(viewport={'width':1280,'height':720});errors=[]
  p.on('pageerror',lambda e:errors.append(str(e)))
  p.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
  await p.goto('http://127.0.0.1:8087/?qa=1');await p.wait_for_function('window.__arenaQA',timeout=30000)
  assert await p.title()=='Robocon 2027 The Pursuit of Mustika Nusantara'
  await p.screenshot(path=str(OUT/'mustika-title.png'))
  # Native Godot fullscreen button, including mouse hover/focus state.
  await p.mouse.click(1240,38);await p.wait_for_timeout(650)
  assert await p.evaluate('!!document.fullscreenElement')
  await p.screenshot(path=str(OUT/'fullscreen-focus.png'))
  await p.mouse.click(1240,38);await p.wait_for_timeout(650)
  assert await p.evaluate('!document.fullscreenElement')
  await menu(p,'FREE');await drive(p,'w',200)
  print('FREE STATE',(await state(p))['menu'],flush=True)
  await p.keyboard.press('Escape');await p.wait_for_timeout(650)
  # A rejected browser pointer-lock request must not turn retry into another pause.
  await p.evaluate("window.realLock=HTMLCanvasElement.prototype.requestPointerLock;HTMLCanvasElement.prototype.requestPointerLock=function(){document.dispatchEvent(new Event('pointerlockerror'));}")
  await menu(p,'RETRY');await p.wait_for_timeout(1600)
  assert not (await state(p))['menu'],'retry repaused after lock rejection'
  start=(await state(p))['state']['robots'][0]['p']
  await drive(p,'w',300)
  assert (await state(p))['state']['robots'][0]['p'][2]<start[2]-.1
  await p.evaluate('()=>{HTMLCanvasElement.prototype.requestPointerLock=window.realLock;}')
  await p.keyboard.press('Escape');await p.wait_for_timeout(650);await menu(p,'RESET')
  await drive(p,'w',1120);await drive(p,'d',820)
  print('TR ENTRY',(await state(p))['state']['robots'][0],flush=True)
  await p.keyboard.press('e');await p.wait_for_timeout(900)
  assert (await state(p))['state']['robots'][0]['job'].get('type')=='climb'
  await p.wait_for_timeout(2500)
  assert abs((await state(p))['state']['robots'][0]['p'][1]-.6)<.01
  await p.screenshot(path=str(OUT/'tr-stair-transfer.png'))
  await p.keyboard.press('Escape');await p.wait_for_timeout(650);await menu(p,'RESET')
  await p.keyboard.press('q');await p.wait_for_timeout(650)
  await drive(p,'w',400);await drive(p,'a',340);await drive(p,'w',4460)
  await drive(p,'d',670)
  print('BR RAMP ENTRY',(await state(p))['state']['robots'][1]['p'],flush=True)
  await drive(p,'s',2400)
  r=(await state(p))['state']['robots'][1]
  assert r['p'][1]>.55,r
  await p.screenshot(path=str(OUT/'br-ramp.png'))
  report={'retry_denied_lock_keeps_playing':True,'tr_stairs':True,'br_ramp':True,'fullscreen_button':True,'title':True,'errors':errors}
  print(report);(OUT/'six-fixes-browser.json').write_text(json.dumps(report,indent=2));assert not errors
  await b.close()
asyncio.run(main())
