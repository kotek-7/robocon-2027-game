"""Real 2v2 queue isolation, seat authority, reconnect and disconnect forfeit."""

import asyncio, json, websockets
from contextlib import AsyncExitStack
from network_helpers import receive, enqueue


async def send(ws, **d):
    await ws.send(json.dumps(d))


async def main():
    async with AsyncExitStack() as stack:

        async def connect():
            return await stack.enter_async_context(
                websockets.connect("ws://127.0.0.1:9080", close_timeout=1)
            )

        solo = await connect()
        await enqueue(solo)
        await receive(solo, "queued")
        players = [await connect() for _ in range(4)]
        for p, name in zip(players, ["はる7", "Blue Bolt", "CPU", "A\u202eB"]):
            await enqueue(p, format="2v2", nickname=name)
            await receive(p, "queued")
        joins = await asyncio.gather(*(receive(p, "joined") for p in players))
        assert [j["robot_id"] for j in joins] == [0, 2, 1, 3]
        assert all(
            j["robot_names"] == ["はる7", "Pilot", "Blue Bolt", "AB"] for j in joins
        )
        assert [j["team"] for j in joins] == [0, 1, 0, 1] and len(
            {j["room"] for j in joins}
        ) == 1
        # The older solo ticket stays separate, and only matches another solo ticket.
        solo2 = await connect()
        await enqueue(solo2)
        sa, sb = await asyncio.gather(receive(solo, "joined"), receive(solo2, "joined"))
        assert sa["room"] == sb["room"] != joins[0]["room"] and sa["robot_id"] == -1
        for p in players[:3]:
            await send(p, type="ready")
        last = await receive(players[2], "ready")
        assert not last["started"]
        await send(players[3], type="ready")
        initial = (await receive(players[2], "state"))["state"]
        # BR client tries to switch/control TR; only its own BR may move.
        for seq in range(1, 26):
            await send(
                players[2],
                type="input",
                seq=seq,
                cmd={"x": 0, "z": -1, "switch": True, "robot_id": 0},
            )
            await asyncio.sleep(0.02)
        await asyncio.sleep(0.5)
        for _ in range(20):
            after = (await receive(players[2], "state"))["state"]
        assert after["robots"][1]["p"][2] < initial["robots"][1]["p"][2] - 0.2
        assert after["robots"][0]["p"] == initial["robots"][0]["p"]
        await players[2].close()
        await asyncio.sleep(0.2)
        players[2] = await connect()
        await send(
            players[2], type="resume", room=joins[2]["room"], token=joins[2]["token"]
        )
        restored = await receive(players[2], "joined")
        assert (
            restored["robot_id"] == 1
            and restored["seat"] == 2
            and restored["robot_names"] == joins[2]["robot_names"]
        )
        # Disconnect the other BR; its team forfeits after the normal 30-second grace.
        await players[3].close()
        async with asyncio.timeout(35):
            while True:
                result = await receive(players[0], "state")
                if result["state"]["finished"]:
                    break
        assert result["reason"] == "disconnect" and result["state"]["winner"] == 0
        print(
            "PASS: isolated 1v1/2v2 queues, four ready seats, fixed robot authority, BR reconnect, team forfeit"
        )


async def run():
    async with asyncio.timeout(50):
        await main()


asyncio.run(run())
