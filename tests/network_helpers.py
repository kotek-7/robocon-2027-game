import json,uuid
async def receive(ws,kind):
    async for raw in ws:
        packet=json.loads(raw)
        if packet['type']==kind:return packet
async def enqueue(ws,ticket=None,revision=1):
    ticket=ticket or uuid.uuid4().hex
    await ws.send(json.dumps({'type':'queue','ticket':ticket,'revision':revision,'protocol':'robocon2027-v2','ruleset':'abu2027-v1.1-fixed-r2'}))
    return ticket
async def match_pair(a,b):
    ticket=await enqueue(a)
    await receive(a,'queued')
    await enqueue(a,ticket)
    await receive(a,'queued')
    await enqueue(b)
    return await receive(a,'joined'),await receive(b,'joined')
