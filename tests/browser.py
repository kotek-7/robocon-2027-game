"""Real browser inputs; ?qa=1 exposes read-only state and button bounds only."""
import asyncio,json,pathlib,time
from playwright.async_api import async_playwright
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'build/qa';OUT.mkdir(parents=True,exist_ok=True)
errors=[]
async def state(p):return await p.evaluate('window.__arenaQA')
async def button(p,name):
 await p.bring_to_front()
 await p.wait_for_function('(name)=>window.__arenaQA?.buttons.some(b=>b.text===name)',arg=name,timeout=10000)
 d=await state(p);b=next(x for x in d['buttons'] if x['text']==name)
 await p.mouse.click(b['x'],b['y']);await p.wait_for_timeout(800)
async def run():
 async with async_playwright() as pw:
  b=await pw.chromium.launch(headless=False,executable_path='/home/kotek/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome',args=['--no-sandbox','--enable-webgl','--use-gl=angle','--use-angle=gl','--ignore-gpu-blocklist','--disable-background-timer-throttling','--disable-renderer-backgrounding'])
  p=await b.new_page(viewport={'width':1280,'height':720})
  p.on('pageerror',lambda e:errors.append(str(e)))
  p.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
  await p.goto('http://127.0.0.1:8087/?qa=1');await p.wait_for_function('window.__arenaQA',timeout=30000)
  await p.screenshot(path=str(OUT/'functional-title.png'))
  await button(p,'FREE')
  print('FREE',flush=True)
  before=await state(p)
  await p.keyboard.down('w');await p.wait_for_timeout(1700);await p.keyboard.up('w');await p.wait_for_timeout(700)
  after=await state(p)
  assert after['state']['robots'][0]['p'][2]<before['state']['robots'][0]['p'][2]-.2
  await p.screenshot(path=str(OUT/'functional-play.png'))
  await p.keyboard.down('w');await p.wait_for_timeout(3600);await p.keyboard.up('w');await p.wait_for_timeout(600)
  await p.keyboard.press('e');await p.wait_for_timeout(1200)
  assert len((await state(p))['state']['robots'][0]['carry'])==1,'stock pickup'
  print('PICKUP',flush=True)
  away=await b.new_page();await away.goto('about:blank');await away.bring_to_front();await away.wait_for_timeout(600)
  await p.bring_to_front();await p.wait_for_timeout(700)
  assert (await state(p))['menu'],'focus loss opens menu'
  await away.close();await button(p,'RETRY')
  assert (await state(p))['state']['robots'][0]['carry']==[]
  print('RETRY',flush=True)
  await p.keyboard.press('q');await p.wait_for_timeout(700)
  assert (await state(p))['state']['active'][0]==1
  await p.keyboard.down('Tab');await p.wait_for_timeout(750);await p.screenshot(path=str(OUT/'functional-overview.png'));await p.keyboard.up('Tab')
  await p.keyboard.press('Escape');await button(p,'RESET')
  assert (await state(p))['state']['elapsed']<3
  await p.keyboard.press('Escape');await button(p,'EXIT')
  await button(p,'VS CPU')
  # Let a full match run naturally while sampling performance and score.
  fps=[]
  deadline=time.monotonic()+300
  while time.monotonic()<deadline:
   await p.wait_for_timeout(5000);d=await state(p);fps.append(d['fps']);print('MATCH',d['state']['elapsed'],d['state']['scores'],'fps',d['fps'],'menu',d['menu'],flush=True)
   if d['state']['finished']:break
   if d['menu']:await button(p,'RESUME')
  d=await state(p)
  assert d['state']['finished'],'180s match did not finish'
  assert d['state']['scores'][1]>250 and d['state']['objects'][52]['where']=='pillar',d['state']['scores']
  await p.screenshot(path=str(OUT/'result.png'))
  await button(p,'AGAIN');assert (await state(p))['state']['elapsed']<3
  await p.keyboard.press('Escape');await button(p,'EXIT')
  await p.set_viewport_size({'width':960,'height':600});await p.wait_for_timeout(800);await p.screenshot(path=str(OUT/'title-small.png'))
  report={'browser':'Chromium 1243 / hardware GL / display :0','renderer':await p.evaluate("(()=>{const g=document.querySelector('canvas').getContext('webgl2');const e=g.getExtension('WEBGL_debug_renderer_info');return e?g.getParameter(e.UNMASKED_RENDERER_WEBGL):g.getParameter(g.RENDERER)})()"),'viewport':[1280,720],'fps_samples':fps,'fps_median':sorted(fps)[len(fps)//2], 'cpu_score':d['state']['scores'],'errors':errors,'checks':['free movement','stock pickup','focus loss','retry returns cargo','robot switch','overview','reset','180 second CPU match with Mustika','result','rematch','960x600 title']}
  (OUT/'browser.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
  assert not errors,errors
  await b.close()
asyncio.run(run())
