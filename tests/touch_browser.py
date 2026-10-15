"""Real Chromium touch events, with mobile viewport and simultaneous pointers."""
import asyncio,json,pathlib
from playwright.async_api import async_playwright
OUT=pathlib.Path(__file__).resolve().parents[1]/'build/qa'
async def state(p):return await p.evaluate('window.__arenaQA')
async def main():
 async with async_playwright() as pw:
  b=await pw.chromium.launch(headless=False,executable_path='/home/kotek/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome',args=['--no-sandbox','--use-gl=angle','--use-angle=gl','--ignore-gpu-blocklist'])
  ctx=await b.new_context(viewport={'width':844,'height':390},has_touch=True,is_mobile=True,device_scale_factor=1)
  p=await ctx.new_page();errors=[]
  p.on('pageerror',lambda e:errors.append(str(e)))
  p.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
  await p.goto('http://127.0.0.1:8087/?qa=1');await p.wait_for_function('window.__arenaQA?.touch',timeout=30000)
  await p.screenshot(path=str(OUT/'touch-title.png'))
  async def menu(name):
   bb=next(x for x in (await state(p))['buttons'] if x['text']==name)
   await p.touchscreen.tap(bb['x'],bb['y']);await p.wait_for_timeout(800)
  async def button(name):
   bb=next(x for x in (await state(p))['touch_buttons'] if x['name']==name)
   await p.touchscreen.tap(bb['x'],bb['y']);await p.wait_for_timeout(650)
  await menu('FREE');s=await state(p);assert not s['menu']
  assert await p.evaluate('document.pointerLockElement===null')
  cdp=await ctx.new_cdp_session(p)
  async def send(kind,points):await cdp.send('Input.dispatchTouchEvent',{'type':kind,'touchPoints':[{'id':i,'x':x,'y':y} for i,x,y in points]})
  before=s['state']['robots'][0]['p'];yaw=s['yaw']
  await send('touchStart',[(1,84,298)])
  await send('touchMove',[(1,84,244)])
  await send('touchStart',[(1,84,244),(2,430,180)])
  await send('touchMove',[(1,84,244),(2,480,190)])
  await p.wait_for_timeout(1200)
  s=await state(p);assert abs(s['yaw']-yaw)>.1
  assert sum((s['state']['robots'][0]['p'][i]-before[i])**2 for i in [0,2])>.3
  # Releasing only the look finger must keep the movement finger active.
  await send('touchEnd',[(2,480,190)]);await p.wait_for_timeout(650)
  assert (await state(p))['move'][1]<-.5
  await send('touchCancel',[]);await p.wait_for_timeout(800)
  assert (await state(p))['move']==[0,0]
  assert sum(abs(x) for x in (await state(p))['state']['robots'][0]['v'])<.01
  await button('switch');assert (await state(p))['state']['active'][0]==1
  await button('overview');assert (await state(p))['overview']
  await button('overview');assert not (await state(p))['overview']
  await p.screenshot(path=str(OUT/'touch-landscape.png'))
  await button('menu');assert (await state(p))['menu']
  await menu('RESET')
  # Ground stock pickup with ACT proves the command is connected to gameplay.
  await send('touchStart',[(1,84,298)]);await send('touchMove',[(1,84,244)])
  await p.wait_for_timeout(5400);await send('touchEnd',[]);await p.wait_for_timeout(700)
  await button('act');await p.wait_for_timeout(800)
  assert len((await state(p))['state']['robots'][0]['carry'])==1
  await button('menu');await menu('RESET')
  await p.set_viewport_size({'width':390,'height':844});await p.wait_for_timeout(1300)
  s=await state(p);assert s['landscape_required'] and s['move']==[0,0]
  elapsed=s['state']['elapsed'];position=s['state']['robots'][0]['p']
  await p.touchscreen.tap(84,740);await p.wait_for_timeout(800)
  assert (await state(p))['state']['robots'][0]['p']==position
  assert (await state(p))['state']['elapsed']==elapsed
  await p.screenshot(path=str(OUT/'touch-portrait.png'))
  await p.set_viewport_size({'width':844,'height':390});await p.wait_for_timeout(1000)
  assert not (await state(p))['landscape_required']
  await button('switch');assert (await state(p))['state']['active'][0]==1
  await button('fullscreen');assert await p.evaluate('!!document.fullscreenElement')
  await button('fullscreen');assert await p.evaluate('!document.fullscreenElement')
  await button('menu');await menu('EXIT')
  report={'touch_move_and_look':True,'single_pointer_release':True,'cancel_releases':True,'switch':True,'pickup':True,'overview':True,'portrait_blocks_play':True,'fullscreen_toggle':True,'no_pointer_lock':True,'errors':errors}
  print(report);(OUT/'touch-browser.json').write_text(json.dumps(report,indent=2));assert not errors
  await b.close()
asyncio.run(main())
