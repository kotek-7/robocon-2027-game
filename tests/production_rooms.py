"""Private-room WSS check: never enters or affects a public matchmaking queue."""
import asyncio
import json
import statistics
import sys
import time
from contextlib import AsyncExitStack
from urllib.parse import urlsplit

import websockets
from network_helpers import receive


async def send(ws, **packet):
    await ws.send(json.dumps(packet))


async def main(endpoint):
    url = urlsplit(endpoint)
    origin = f"{'https' if url.scheme == 'wss' else 'http'}://{url.netloc}"
    async with websockets.connect(endpoint, origin=origin) as probe:
        latencies = []
        for _ in range(30):
            start = time.perf_counter()
            await send(probe, type="queue", protocol="deployment-probe")
            assert (await receive(probe, "error"))["text"] == "Reload to update"
            latencies.append(1000 * (time.perf_counter() - start))
        print(f"Application RTT: median {statistics.median(latencies):.2f} ms, p95 {sorted(latencies)[28]:.2f} ms, max {max(latencies):.2f} ms")
    for format, count in [("1v1", 2), ("2v2", 4)]:
        async with AsyncExitStack() as stack:
            async def connect():
                return await stack.enter_async_context(websockets.connect(endpoint, origin=origin, max_queue=None))
            host = await connect()
            await send(host, type="create_room", format=format, protocol="robocon2027-v4", ruleset="abu2027-v1.1-fixed-r5", nickname="MigrationCheck")
            joined = await receive(host, "joined")
            assert joined["private"]
            players = [host]
            joins = [joined]
            for seat in range(1, count):
                guest = await connect()
                await send(guest, type="join_room", format=format, room=joined["room"], protocol="robocon2027-v4", ruleset="abu2027-v1.1-fixed-r5", nickname=f"Check{seat}")
                joins.append(await receive(guest, "joined"))
                players.append(guest)
            await send(host, type="start_room")
            states = await asyncio.gather(*(receive(ws, "state") for ws in players))
            assert all(s["state"]["mode"] == "online" for s in states)
            initial = states[0]["state"]["robots"][0]["p"][2]
            async def movement():
                for seq in range(1, 25):
                    await send(host, type="input", seq=seq, cmd={"x": 0, "z": -1})
                    await asyncio.sleep(0.02)
            moves = asyncio.create_task(movement())
            times = []
            for _ in range(25):
                state = await receive(host, "state")
                times.append(time.perf_counter())
            await moves
            assert state["state"]["robots"][0]["p"][2] < initial - 0.1
            intervals = [(b-a)*1000 for a,b in zip(times,times[1:])]
            await players[-1].close()
            resumed = await connect()
            await send(resumed, type="resume", room=joined["room"], token=joins[-1]["token"])
            restored = await receive(resumed, "joined")
            assert restored["seat"] == count-1
            await receive(resumed, "state")
            print(f"PASS {format}: {count} players, movement, token resume; state interval median {statistics.median(intervals):.2f} ms")


async def run():
    async with asyncio.timeout(90):
        await main(sys.argv[1])

if __name__ == "__main__":
    asyncio.run(run())
