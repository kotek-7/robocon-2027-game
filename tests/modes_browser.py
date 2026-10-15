"""CPU handoff and four actual browser clients using the 2v2 UI."""
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
  pages=[];errors=[]
  for _ in range(4):
   p=await browser.new_page(viewport={'width':1280,'height':720});pages.append(p)
   p.on('pageerror',lambda e:errors.append(str(e)))
   p.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
   await p.goto('http://127.0.0.1:8087/?qa=1');await p.wait_for_function('window.__arenaQA',timeout=30000)
  a=pages[0];await a.bring_to_front();await a.screenshot(path=str(OUT/'large-title.png'))
  await click(a,'VS CPU');await a.wait_for_timeout(4000)
  d=await state(a);assert d['state']['robots'][1]['p'][2]<4.5,d
  assert d['state']['robots'][0]['p']==[-4.8,0,4.9] or abs(d['state']['robots'][0]['p'][2]-4.9)<.01
  await a.keyboard.press('q');await a.wait_for_timeout(2000)
  d=await state(a);assert d['state']['active'][0]==1 and d['state']['robots'][0]['p'][2]<4
  await a.screenshot(path=str(OUT/'cpu-partner.png'))
  await a.keyboard.press('Escape');await click(a,'EXIT')
  for p in pages:
   await click(p,'ONLINE');await p.screenshot(path=str(OUT/'online-formats.png'))
   await click(p,'2 vs 2')
  for p in pages:await p.wait_for_function("window.__arenaQA?.mode==='online'",timeout=15000)
  states=[await state(p) for p in pages]
  assert [s['robot_id'] for s in states]==[0,2,1,3],states
  assert len({s['room'] for s in states})==1
  for p in [pages[2],pages[3]]:
   await click(p,'RESUME');rid=(await state(p))['robot_id']
   before=(await state(p))['state']['robots'][rid]['p']
   await p.keyboard.press('q');await p.keyboard.down('w');await p.wait_for_timeout(1400);await p.keyboard.up('w');await p.wait_for_timeout(700)
   s=await state(p);assert s['state']['active'][s['team']]==rid
   assert s['state']['robots'][rid]['p'][2]<before[2]-.3
  await pages[3].screenshot(path=str(OUT/'2v2-br.png'))
  await pages[0].bring_to_front();await pages[0].wait_for_timeout(1000)
  s=await state(pages[0]);assert s['state']['robots'][1]['p'][2]<4 and s['state']['robots'][3]['p'][2]<4
  report={'cpu_partner':True,'switch_handoff':True,'four_browser_match':True,'fixed_br_control':True,'state_sync':True,'errors':errors}
  (OUT/'modes-browser.json').write_text(json.dumps(report,indent=2));print(report);assert not errors
  await browser.close()
asyncio.run(main())
