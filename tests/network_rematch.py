"""A complete authoritative match and mutual rematch, without changing its clock."""
import asyncio,json,websockets
async def send(ws,**d):await ws.send(json.dumps(d))
async def until(ws,predicate):
 async for raw in ws:
  d=json.loads(raw)
  if predicate(d):return d
async def main():
 async with websockets.connect('ws://127.0.0.1:9080') as a, websockets.connect('ws://127.0.0.1:9080') as b:
  from network_helpers import match_pair
  await match_pair(a,b)
  await send(a,type='ready');await send(b,type='ready')
  async with asyncio.timeout(190):
   await asyncio.gather(until(a,lambda d:d['type']=='state' and d['state']['finished']),until(b,lambda d:d['type']=='state' and d['state']['finished']))
  await send(a,type='rematch');await send(b,type='rematch')
  async with asyncio.timeout(5):
   sa,sb=await asyncio.gather(until(a,lambda d:d['type']=='state' and not d['state']['finished']),until(b,lambda d:d['type']=='state' and not d['state']['finished']))
  assert sa['state']['elapsed']<2 and sb['state']['scores']==[0,0]
  print('PASS: natural 180-second online match and mutual rematch')
asyncio.run(main())
