"""Real local sockets: roster seats, names, departures and reconnection."""
import asyncio
import json
from contextlib import AsyncExitStack

import websockets
from network_helpers import enqueue, receive


async def send(ws, **packet):
    await ws.send(json.dumps(packet))


async def room_request(ws, kind, name, room=""):
    await send(ws, type=kind, nickname=name, room=room, protocol="robocon2027-v4", ruleset="abu2027-v1.1-fixed-r5")


async def main():
    async with AsyncExitStack() as stack:
        async def connect():
            return await stack.enter_async_context(websockets.connect("ws://127.0.0.1:9080"))
        host, guest = await connect(), await connect()
        await room_request(host, "create_room", "赤チーム")
        joined = await receive(host, "joined")
        roster = (await receive(host, "lobby"))["members"]
        assert roster[0]["nickname"] == "赤チーム" and roster[0]["host"]
        assert all(m["nickname"] == "CPU" and m["status"] == "open" for m in roster[1:])
        await room_request(guest, "join_room", "BluePilot", joined["room"])
        guest_join = await receive(guest, "joined")
        roster = (await receive(host, "lobby"))["members"]
        assert [(m["seat"], m["team"], m["role"]) for m in roster] == [(0,0,"TR"),(1,1,"TR"),(2,0,"BR"),(3,1,"BR")]
        assert roster[1]["nickname"] == "BluePilot"
        assert not any("token" in m for m in roster)
        await guest.close()
        roster = (await receive(host, "lobby"))["members"]
        assert roster[1]["status"] == "reconnecting" and roster[1]["nickname"] == "BluePilot"
        resumed = await connect()
        await send(resumed, type="resume", room=joined["room"], token=guest_join["token"])
        await receive(resumed, "joined")
        assert (await receive(host, "lobby"))["members"][1]["status"] == "connected"
        await send(resumed, type="leave")
        roster = (await receive(host, "lobby"))["members"]
        assert roster[1]["status"] == "open" and roster[1]["nickname"] == "CPU"
        replacement = await connect()
        await room_request(replacement, "join_room", "NewPilot", joined["room"])
        await receive(replacement, "joined")
        assert (await receive(host, "lobby"))["members"][1]["nickname"] == "NewPilot"
        await send(host, type="leave")
        while True:
            lobby = await receive(replacement, "lobby")
            if lobby["count"] == 1:
                break
        assert lobby["host"] and lobby["members"][1]["host"]
        assert lobby["members"][0]["status"] == "open"
        for format, count in [("1v1", 2), ("2v2", 4)]:
            players = [await connect() for _ in range(count)]
            for i, player in enumerate(players):
                await enqueue(player, format=format, nickname=f"Pilot{i}")
            joins = await asyncio.gather(*(receive(p, "joined") for p in players))
            assert all(j["members"] == joins[0]["members"] for j in joins)
            assert [m["nickname"] for m in joins[0]["members"]] == [f"Pilot{i}" for i in range(count)]
            assert len(joins[0]["members"]) == count
            for p in players:
                await send(p, type="leave")
    print("PASS: private roster join/leave/resume/host transfer and automatic 1v1/2v2 members")


async def run():
    async with asyncio.timeout(20):
        await main()

asyncio.run(run())
