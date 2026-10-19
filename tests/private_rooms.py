"""Code-based rooms against the real headless server on port 9080."""

import asyncio
import json
from contextlib import AsyncExitStack
import websockets
from network_helpers import enqueue, receive


async def send(ws, **packet):
    await ws.send(json.dumps(packet))


async def request(ws, kind, format="1v1", room="", nickname="Pilot"):
    await send(
        ws,
        type=kind,
        format=format,
        room=room,
        nickname=nickname,
        protocol="robocon2027-v4",
        ruleset="abu2027-v1.1-fixed-r5",
    )


async def main():
    async with AsyncExitStack() as stack:

        async def connect():
            return await stack.enter_async_context(
                websockets.connect(
                    "ws://127.0.0.1:9080", close_timeout=1, max_queue=None
                )
            )

        for humans in [1, 2, 3, 4]:
            format, capacity = "2v2", 4
            host = await connect()
            await request(host, "create_room", format, nickname="Host")
            joined = await receive(host, "joined")
            code = joined["room"]
            assert len(code) == 6 and joined["private"]
            assert (await receive(host, "lobby"))["count"] == 1
            await send(host, type="ready")
            assert not (await receive(host, "ready"))["started"]
            # A public queue must never fill a private seat.
            public = [await connect(), await connect()]
            for ws in public:
                await enqueue(ws)
            public_joins = await asyncio.gather(
                *(receive(ws, "joined") for ws in public)
            )
            assert public_joins[0]["room"] == public_joins[1]["room"] != code
            assert not public_joins[0]["private"]
            bad = await connect()
            await request(bad, "join_room", format, "ZZZZZZ")
            assert "not found" in (await receive(bad, "error"))["text"]
            # Explicit lobby exit frees the seat immediately.
            guest = await connect()
            await request(guest, "join_room", format, code.lower())
            await receive(guest, "joined")
            await send(guest, type="leave")
            await guest.wait_closed()
            players = [host]
            joins = [joined]
            for seat in range(1, humans):
                ws = await connect()
                await request(ws, "join_room", format, code.lower(), f"Player{seat}")
                joins.append(await receive(ws, "joined"))
                players.append(ws)
            assert [j["seat"] for j in joins] == list(range(humans))
            assert [j["robot_id"] for j in joins] == [0, 2, 1, 3][:humans]
            if humans == 4:
                await request(bad, "join_room", format, code)
                assert "full" in (await receive(bad, "error"))["text"]
            for ws in players[1:]:
                await send(ws, type="ready")
            if humans > 1:
                await send(players[1], type="start_room")
                await send(players[1], type="ready")
                assert not (await receive(players[1], "ready"))["started"]
            await send(host, type="start_room")
            expected_controls = {1: [-1], 2: [-1, -1], 3: [0, -1, 1], 4: [0, 2, 1, 3]}[
                humans
            ]
            for ws, control in zip(players, expected_controls):
                while True:
                    ready = await receive(ws, "ready")
                    if ready["started"]:
                        assert ready["robot_id"] == control
                        break
            states = await asyncio.gather(*(receive(ws, "state") for ws in players))
            assert all(s["state"]["mode"] == "online" for s in states)
            if humans < 4:
                initial = states[0]["state"]
                for _ in range(15):
                    later = (await receive(host, "state"))["state"]
                missing = [0, 2, 1, 3][humans:]
                assert any(
                    later["robots"][rid]["p"] != initial["robots"][rid]["p"]
                    for rid in missing
                )
            for ws in players:
                await send(ws, type="input", seq=1, cmd={"switch": True})
            while True:
                switched = await receive(host, "state")
                if switched["state"]["elapsed"] > states[0]["state"]["elapsed"] + 1.5:
                    break
            assert (
                switched["state"]["active"]
                == {1: [1, 2], 2: [1, 3], 3: [0, 3], 4: [0, 2]}[humans]
            )
            if humans <= 2:
                assert (
                    switched["robot_names"][1] == "Host"
                    and switched["robot_names"][0] == "CPU"
                )
            await request(bad, "join_room", format, code)
            assert "in progress" in (await receive(bad, "error"))["text"]
            # Resume uses the private room token, not the publicly shareable code alone.
            await players[-1].close()
            await asyncio.sleep(0.15)
            resumed = await connect()
            await send(resumed, type="resume", room=code, token=joins[-1]["token"])
            rejoined = await receive(resumed, "joined")
            assert (
                rejoined["seat"] == humans - 1
                and rejoined["robot_id"] == expected_controls[-1]
            )
            await receive(resumed, "state")
            await asyncio.gather(
                *(ws.close() for ws in players + public + [bad, resumed])
            )
            print(
                f"PASS: {humans} humans + {4 - humans} CPUs, host-only start, code, public isolation, exit and resume"
            )


async def run():
    async with asyncio.timeout(30):
        await main()


asyncio.run(run())
