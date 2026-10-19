"""1v1 humans with server CPU partners: queue isolation, handoff and reconnect."""

import asyncio, json, websockets
from contextlib import AsyncExitStack
from network_helpers import receive, enqueue


async def send(ws, **d):
    await ws.send(json.dumps(d))


async def state_after(ws, elapsed):
    while True:
        s = (await receive(ws, "state"))["state"]
        if s["elapsed"] >= elapsed:
            return s


async def main():
    async with AsyncExitStack() as stack:

        async def connect():
            return await stack.enter_async_context(
                websockets.connect("ws://127.0.0.1:9080", close_timeout=1)
            )

        solo = await connect()
        await enqueue(solo, format="2v2")
        await receive(solo, "queued")
        players = [await connect() for _ in range(2)]
        for p, name in zip(players, ["はる7", "Blue Bolt"]):
            await enqueue(p, format="1v1", nickname=name)
            await receive(p, "queued")
        joins = await asyncio.gather(*(receive(p, "joined") for p in players))
        assert [j["robot_id"] for j in joins] == [-1, -1]
        assert all(
            j["robot_names"] == ["はる7", "はる7", "Blue Bolt", "Blue Bolt"]
            for j in joins
        )
        assert [j["team"] for j in joins] == [0, 1] and len(
            {j["room"] for j in joins}
        ) == 1
        others = [solo] + [await connect() for _ in range(3)]
        for p in others[1:]:
            await enqueue(p, format="2v2")
        four = await asyncio.gather(*(receive(p, "joined") for p in others))
        assert [j["robot_id"] for j in four] == [0, 2, 1, 3]
        assert (
            len({j["room"] for j in four}) == 1 and four[0]["room"] != joins[0]["room"]
        )
        await send(players[0], type="ready")
        assert not (await receive(players[0], "ready"))["started"]
        await send(players[1], type="ready")
        initial = await state_after(players[0], 0.1)
        after = await state_after(players[0], 2)
        for rid in [1, 3]:
            assert after["robots"][rid]["p"] != initial["robots"][rid]["p"], (
                "CPU partner must move"
            )
        for rid in [0, 2]:
            assert after["robots"][rid]["p"] == initial["robots"][rid]["p"], (
                "human must remain idle"
            )
        # Both humans switch to BR; CPU takes over TR. Forged robot_id is ignored.
        for p in players:
            await send(p, type="input", seq=1, cmd={"switch": True, "robot_id": 3})
        switched = await state_after(players[0], after["elapsed"] + 1)
        assert switched["active"] == [1, 3]
        for rid in [0, 2]:
            assert switched["robots"][rid]["p"] != initial["robots"][rid]["p"]
        # Existing stair jobs may finish after switching; wait for them and braking.
        switched = await state_after(players[0], switched["elapsed"] + 4)
        idle = await state_after(players[0], switched["elapsed"] + 1)
        for rid in [1, 3]:
            assert idle["robots"][rid]["p"] == switched["robots"][rid]["p"], (
                "CPU must release human robot"
            )
        await players[0].close()
        await asyncio.sleep(0.2)
        players[0] = await connect()
        await send(
            players[0], type="resume", room=joins[0]["room"], token=joins[0]["token"]
        )
        restored = await receive(players[0], "joined")
        assert (
            restored["robot_id"] == -1
            and restored["seat"] == 0
            and restored["robot_names"] == joins[0]["robot_names"]
        )
        assert (await receive(players[0], "state"))["state"]["active"] == [1, 3]
        await players[1].close()
        async with asyncio.timeout(35):
            while True:
                result = await receive(players[0], "state")
                if result["state"]["finished"]:
                    break
        assert result["reason"] == "disconnect" and result["state"]["winner"] == 0
        print(
            "PASS: isolated queues, two humans, two CPU partners, switch handoff, reconnect and team forfeit"
        )


async def run():
    async with asyncio.timeout(50):
        await main()


asyncio.run(run())
