"""A natural 180-second match and unanimous rematch (1v1 or 2v2)."""
import asyncio,json,sys,websockets
from contextlib import AsyncExitStack
from network_helpers import enqueue,receive
async def send(ws,**d):await ws.send(json.dumps(d))
async def until(ws,predicate):
 async for raw in ws:
  d=json.loads(raw)
  if predicate(d):return d
async def main():
 format='2v2' if '--2v2' in sys.argv else '1v1'
 async with AsyncExitStack() as stack:
  players=[await stack.enter_async_context(websockets.connect('ws://127.0.0.1:9080')) for _ in range(4 if format=='2v2' else 2)]
  for p in players:await enqueue(p,format=format)
  await asyncio.gather(*(receive(p,'joined') for p in players))
  for p in players:await send(p,type='ready')
  async with asyncio.timeout(190):
   await asyncio.gather(*(until(p,lambda d:d['type']=='state' and d['state']['finished']) for p in players))
  for p in players[:-1]:await send(p,type='rematch')
  # No reset before the final player's consent.
  d=await until(players[-1],lambda d:d['type']=='state');assert d['state']['finished']
  await send(players[-1],type='rematch')
  async with asyncio.timeout(5):
   states=await asyncio.gather(*(until(p,lambda d:d['type']=='state' and not d['state']['finished']) for p in players))
  assert all(d['state']['elapsed']<2 and d['state']['scores']==[0,0] for d in states)
  print('PASS:',format,'natural 180-second online match and unanimous rematch')
asyncio.run(main())
