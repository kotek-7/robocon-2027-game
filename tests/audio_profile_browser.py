"""Real UI profile persistence, CPU nameplates and audio lifecycle."""
import asyncio,json,pathlib
from playwright.async_api import async_playwright
OUT=pathlib.Path(__file__).resolve().parents[1]/'build/qa'
async def state(p):return await p.evaluate('window.__arenaQA')
async def click(p,name):
 await p.wait_for_function('(name)=>window.__arenaQA?.buttons.some(b=>b.text===name)',arg=name,timeout=10000)
 b=next(x for x in (await state(p))['buttons'] if x['text']==name)
 await p.mouse.click(b['x'],b['y']);await p.wait_for_timeout(800)
async def main():
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(headless=False,executable_path='/home/kotek/.cache/ms-playwright/chromium-1243/chrome-linux64/chrome',args=['--no-sandbox','--use-gl=angle','--use-angle=gl','--ignore-gpu-blocklist'])
  context=await browser.new_context(viewport={'width':1280,'height':720})
  p=await context.new_page();errors=[]
  await p.add_init_script("window.testAudioContexts=[];const Base=window.AudioContext;window.AudioContext=class extends Base{constructor(...a){super(...a);window.testAudioContexts.push(this);}};")
  p.on('pageerror',lambda e:errors.append(str(e)))
  p.on('console',lambda m:errors.append(m.text) if m.type=='error' else None)
  # Hold the engine fetch briefly to inspect the real custom loading screen.
  gate=asyncio.Event()
  async def delay(route):await gate.wait();await route.continue_()
  await p.route('**/index.wasm',delay)
  await p.goto('http://127.0.0.1:8087/?qa=1',wait_until='domcontentloaded')
  await p.wait_for_timeout(800);await p.screenshot(path=str(OUT/'field-loading.png'))
  assert 'field-backdrop.jpg' in await p.locator('#status').evaluate('(el)=>getComputedStyle(el).backgroundImage')
  gate.set();await p.wait_for_function('window.__arenaQA',timeout=60000)
  first=(await state(p))['nickname'];assert first and first!='Pilot'
  await p.mouse.click(110,38);await p.wait_for_timeout(700)
  await p.get_by_role('textbox',name='Nickname').fill('はる7')
  await p.screenshot(path=str(OUT/'profile-editor.png'));await click(p,'OK')
  assert (await state(p))['nickname']=='はる7'
  assert json.loads(await p.evaluate("localStorage.getItem('mustika-profile')"))['nickname']=='はる7'
  await p.reload();await p.wait_for_function('window.__arenaQA',timeout=60000)
  assert (await state(p))['nickname']=='はる7'
  await click(p,'VS CPU');await p.wait_for_timeout(1500)
  d=await state(p);assert 'はる7' in d['names'] and d['names'].count('CPU')==3,d['names']
  assert d['music_playing'] and d['audio'].get('start',0)>0
  assert await p.evaluate("window.testAudioContexts.some(c=>c.state==='running')")
  await p.keyboard.press('q');await p.keyboard.down('w');await p.wait_for_timeout(1300);await p.keyboard.up('w')
  await p.wait_for_timeout(700);d=await state(p);assert d['audio'].get('switch',0)>0
  await p.screenshot(path=str(OUT/'nickname-cpu.png'))
  await p.keyboard.press('Escape');await p.wait_for_timeout(900)
  assert (await state(p))['motors']==0
  await click(p,'RETRY');await p.wait_for_timeout(1000)
  assert (await state(p))['audio'].get('retry',0)>0
  # This desktop host keeps background tabs focused; inject visibility events to
  # exercise the browser-to-Godot callback without claiming an OS focus check.
  await p.evaluate("Object.defineProperty(document,'hidden',{configurable:true,value:true});document.dispatchEvent(new Event('visibilitychange'))")
  await p.wait_for_timeout(300)
  assert await p.evaluate('window.__arenaAudioBackground===true')
  await p.evaluate("delete document.hidden;document.dispatchEvent(new Event('visibilitychange'))")
  await p.wait_for_timeout(700);assert not (await state(p))['music_paused']
  report={'loading_field':True,'nickname_persistence':True,'japanese_name':True,'cpu_tags':True,'bgm_started':True,'switch_retry_se':True,'pause_stops_motion_audio':True,'simulated_visibility_pauses_music':True,'errors':errors}
  print(report);(OUT/'audio-profile-browser.json').write_text(json.dumps(report,indent=2));assert not errors
  await browser.close()
asyncio.run(main())
