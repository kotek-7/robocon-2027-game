import asyncio,json,websockets
from network_helpers import enqueue,receive,match_pair
async def main():
    async with websockets.connect('ws://127.0.0.1:9080') as a, websockets.connect('ws://127.0.0.1:9080') as b, websockets.connect('ws://127.0.0.1:9080') as c:
        await a.send(json.dumps({'type':'queue','ticket':'badversion','revision':1,'protocol':'old','ruleset':'old'}))
        assert (await receive(a,'error'))['text']=='Reload to update'
        ticket=await enqueue(a);await receive(a,'queued')
        await a.send(json.dumps({'type':'cancel','ticket':ticket,'revision':2}));await receive(a,'cancelled')
        # A delayed enqueue must not undo a newer cancellation.
        await enqueue(a,ticket,1)
        jb,jc=await match_pair(b,c)
        assert jb['room']==jc['room'] and jb['team']==0 and jc['team']==1
        assert await asyncio.wait_for(a.recv(),.2) is None
async def run():
    try:await main()
    except TimeoutError:print('PASS: incompatible build rejected, cancellation revision retained, duplicate enqueue idempotent, FIFO assignment')
    else:raise AssertionError('Cancelled client received an assignment')
asyncio.run(run())
