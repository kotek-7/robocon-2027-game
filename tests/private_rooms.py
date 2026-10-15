"""Code-based rooms against the real headless server on port 9080."""
import asyncio
import json
from contextlib import AsyncExitStack
import websockets
from network_helpers import enqueue, receive

async def send(ws, **packet):
    await ws.send(json.dumps(packet))

async def request(ws, kind, format='1v1', room='', nickname='Pilot'):
    await send(ws, type=kind, format=format, room=room, nickname=nickname,
               protocol='robocon2027-v4', ruleset='abu2027-v1.1-fixed-r5')

async def main():
    async with AsyncExitStack() as stack:
        async def connect():
            return await stack.enter_async_context(websockets.connect('ws://127.0.0.1:9080'))
        for format, capacity in [('1v1', 2), ('2v2', 4)]:
            host = await connect()
            await request(host, 'create_room', format, nickname='Host')
            joined = await receive(host, 'joined')
            code = joined['room']
            assert len(code) == 6 and joined['private']
            assert (await receive(host, 'lobby'))['count'] == 1
            await send(host, type='ready')
            assert not (await receive(host, 'ready'))['started']
            # A public queue must never fill a private seat.
            public = [await connect(), await connect()]
            for ws in public:
                await enqueue(ws)
            public_joins = await asyncio.gather(*(receive(ws, 'joined') for ws in public))
            assert public_joins[0]['room'] == public_joins[1]['room'] != code
            assert not public_joins[0]['private']
            bad = await connect()
            await request(bad, 'join_room', format, 'ZZZZZZ')
            assert '見つかりません' in (await receive(bad, 'error'))['text']
            await request(bad, 'join_room', '2v2' if format == '1v1' else '1v1', code)
            assert '人数' in (await receive(bad, 'error'))['text']
            # Explicit lobby exit frees the seat immediately.
            guest = await connect()
            await request(guest, 'join_room', format, code.lower())
            await receive(guest, 'joined')
            await send(guest, type='leave')
            await guest.wait_closed()
            players = [host]
            joins = [joined]
            for seat in range(1, capacity):
                ws = await connect()
                await request(ws, 'join_room', format, code.lower(), f'Player{seat}')
                joins.append(await receive(ws, 'joined'))
                players.append(ws)
            assert [j['seat'] for j in joins] == list(range(capacity))
            assert [j['robot_id'] for j in joins] == ([-1, -1] if capacity == 2 else [0, 2, 1, 3])
            await request(bad, 'join_room', format, code)
            assert '満員' in (await receive(bad, 'error'))['text']
            for ws in players[1:]:
                await send(ws, type='ready')
            states = await asyncio.gather(*(receive(ws, 'state') for ws in players))
            assert all(s['state']['mode'] == 'online' for s in states)
            await request(bad, 'join_room', format, code)
            assert '対戦中' in (await receive(bad, 'error'))['text']
            # Resume uses the private room token, not the publicly shareable code alone.
            await players[-1].close()
            await asyncio.sleep(.15)
            resumed = await connect()
            await send(resumed, type='resume', room=code, token=joins[-1]['token'])
            assert (await receive(resumed, 'joined'))['seat'] == capacity - 1
            await receive(resumed, 'state')
            print(f'PASS: {format} private code, public isolation, validation, exit, seats, ready and resume')

async def run():
    async with asyncio.timeout(20):
        await main()
asyncio.run(run())
