"""Drive the BR to both CAD stair entrances with real keyboard input."""
import asyncio,json,pathlib
from playwright.async_api import async_playwright
OUT=pathlib.Path(__file__).resolve().parents[1]/'build/qa'
async def state(p):return await p.evaluate('window.__arenaQA')
async def drive(p,key,ms):
 await p.keyboard.down(key);await p.wait_for_timeout(ms);await p.keyboard.up(key);await p.wait_for_timeout(650)
async def main():
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(headless=False,executable_path='/home/kotek/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome',args=['--no-sandbox','--use-gl=angle','--use-angle=gl','--ignore-gpu-blocklist'])
  p=await browser.new_page(viewport={'width':1280,'height':720});errors=[]
  p.on('pageerror',lambda e:errors.append(str(e)))
  p.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
  await p.goto('http://127.0.0.1:8087/?qa=1');await p.wait_for_function('window.__arenaQA',timeout=30000)
  await p.screenshot(path=str(OUT/'stadium-title.png'))
  b=next(b for b in (await state(p))['buttons'] if b['text']=='FREE')
  await p.mouse.click(b['x'],b['y']);await p.wait_for_timeout(800)
  await p.keyboard.press('q');await p.wait_for_timeout(600)
  await drive(p,'d',400);await drive(p,'w',1120)
  print('ENTRY', (await state(p))['state']['robots'][1],flush=True)
  await p.screenshot(path=str(OUT/'stairs-entry.png'))
  await p.keyboard.press('e');await p.wait_for_timeout(1100)
  r=(await state(p))['state']['robots'][1];assert r['job'].get('type')=='climb',r
  await p.screenshot(path=str(OUT/'stairs-climbing.png'))
  await p.keyboard.press('q');await p.wait_for_timeout(2500)
  d=await state(p);assert d['state']['active'][0]==0
  assert abs(d['state']['robots'][1]['p'][1]-.6)<.01 and not d['state']['robots'][1]['job']
  await p.keyboard.press('q');await p.wait_for_timeout(650)
  await drive(p,'d',710);await drive(p,'w',800)
  print('L2 ENTRY',(await state(p))['state']['robots'][1],flush=True)
  await p.keyboard.press('e');await p.wait_for_timeout(800)
  r=(await state(p))['state']['robots'][1];assert r['job'].get('type')=='climb',r
  await p.wait_for_timeout(1800)
  r=(await state(p))['state']['robots'][1];assert abs(r['p'][1]-.9)<.01 and not r['job'],r
  await p.keyboard.down('Tab');await p.wait_for_timeout(900);await p.screenshot(path=str(OUT/'stadium-overview.png'));await p.keyboard.up('Tab')
  samples=[]
  for i in range(6):await p.wait_for_timeout(1000);samples.append((await state(p))['fps'])
  await p.screenshot(path=str(OUT/'stadium-play.png'))
  report={'gnd_l1':True,'l1_l2':True,'inactive_climb_finishes':True,'fps_samples':samples,'errors':errors}
  print(report);(OUT/'stairs-browser.json').write_text(json.dumps(report,indent=2));assert not errors
  await browser.close()
asyncio.run(main())
