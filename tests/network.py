"""End-to-end tests against the real headless room server on port 9080."""

import asyncio, json, websockets


async def receive(ws, kind):
    for _ in range(100):
        d = json.loads(await asyncio.wait_for(ws.recv(), 3))
        if d["type"] == kind:
            return d
    raise AssertionError("Missing " + kind)


async def send(ws, **d):
    await ws.send(json.dumps(d))


async def main():
    a = await websockets.connect("ws://127.0.0.1:9080")
    b = await websockets.connect("ws://127.0.0.1:9080")
    from network_helpers import match_pair

    ja, jb = await match_pair(a, b)
    assert ja["team"] == 0 and jb["team"] == 1
    await send(a, type="ready")
    await send(b, type="ready")
    sa = (await receive(a, "state"))["state"]
    sb = (await receive(b, "state"))["state"]
    assert sa["objects"] == sb["objects"] and sa["scores"] == sb["scores"]
    start = sa["robots"][0]["p"]
    for seq in range(1, 25):
        await send(a, type="input", seq=seq, cmd={"x": 0, "z": -1})
        await asyncio.sleep(0.02)
    for _ in range(12):
        sa = (await receive(a, "state"))["state"]
    assert sa["robots"][0]["p"][2] < start[2] - 0.1
    # Stale movement inputs must decay when a tab stops transmitting.
    await asyncio.sleep(0.8)
    for _ in range(25):
        sa = (await receive(a, "state"))["state"]
    assert abs(sa["robots"][0]["v"][2]) < 0.01
    await a.close()
    a = await websockets.connect("ws://127.0.0.1:9080")
    await send(a, type="resume", room=ja["room"], token=ja["token"])
    restored = await receive(a, "joined")
    assert restored["team"] == 0 and restored["room"] == ja["room"]
    sr = (await receive(a, "state"))["state"]
    assert sr["elapsed"] > sa["elapsed"]
    await a.close()
    # Consume snapshots continuously to verify the real 30-second grace period.
    before = sr["elapsed"]
    ended = None
    async with asyncio.timeout(35):
        while True:
            packet = await receive(b, "state")
            if packet["state"]["finished"]:
                ended = packet
                break
    assert ended["reason"] == "disconnect" and ended["state"]["winner"] == 1
    assert ended["state"]["elapsed"] >= before + 29
    print(
        "PASS: automatic FIFO matchmaking, ready, shared state, authoritative movement, stale-input stop, token resume, 30-second disconnect forfeit with running clock"
    )
    await b.close()


asyncio.run(main())
