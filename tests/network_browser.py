"""Two real browser clients create/join/ready using the shipped UI."""
import asyncio,json,pathlib
from playwright.async_api import async_playwright
OUT=pathlib.Path(__file__).resolve().parents[1]/'build/qa'
async def state(p):return await p.evaluate('window.__arenaQA')
async def click(p,name):
 await p.bring_to_front()
 await p.wait_for_function('(name)=>window.__arenaQA?.buttons.some(b=>b.text===name)',arg=name,timeout=10000)
 b=next(x for x in (await state(p))['buttons'] if x['text']==name)
 await p.mouse.click(b['x'],b['y']);await p.wait_for_timeout(800)
async def main():
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(headless=False,executable_path='/home/kotek/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome',args=['--no-sandbox','--use-gl=angle','--use-angle=gl','--ignore-gpu-blocklist','--disable-background-timer-throttling','--disable-renderer-backgrounding'])
  a=await browser.new_page(viewport={'width':1280,'height':720});b=await browser.new_page(viewport={'width':1280,'height':720})
  errors=[]
  for p in [a,b]:
   p.on('pageerror',lambda e:errors.append(str(e)))
   p.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
   await p.goto('http://127.0.0.1:8087/?qa=1');await p.wait_for_function('window.__arenaQA',timeout=30000)
  await click(a,'ONLINE');await a.wait_for_timeout(1000)
  assert not any(x['text'] in ['CREATE','JOIN','READY'] for x in (await state(a))['buttons'])
  await click(b,'ONLINE')
  await b.wait_for_function("window.__arenaQA?.mode==='online'",timeout=10000)
  if (await state(b))['menu']:await click(b,'RESUME')
  before=(await state(b))['state']['robots'][2]['p']
  await b.keyboard.down('w');await b.wait_for_timeout(1500);await b.keyboard.up('w');await b.wait_for_timeout(700)
  sb=await state(b)
  assert sb['state']['robots'][2]['p'][2]<before[2]-.2
  await a.bring_to_front();await a.wait_for_timeout(1000);sa=await state(a)
  assert sa['room']==sb['room'] and sa['room']
  room=sa['room']
  assert sa['state']['scores']==sb['state']['scores']
  assert abs(sa['state']['robots'][2]['p'][2]-sb['state']['robots'][2]['p'][2])<.25
  assert sa['state']['elapsed']>0
  await a.screenshot(path=str(OUT/'online.png'))
  report={'automatic_matchmaking':True,'two_browser_state_sync':True,'scores':sa['state']['scores'],'errors':errors}
  (OUT/'network-browser.json').write_text(json.dumps(report,indent=2));print(report)
  assert not errors,errors
  await browser.close()
asyncio.run(main())
