"""Local Wrangler -> direct DO Container API -> Godot integration check."""

import asyncio
import json
import sys
from urllib.parse import urlsplit

import websockets
from deployment_smoke import check
from network_helpers import receive


async def main(endpoint):
    url = urlsplit(endpoint)
    if url.hostname not in ("localhost", "127.0.0.1"):
        raise ValueError("This test allocates a room; use a local endpoint")
    origin = f"http://{url.netloc}"
    # First upgrades hit the same cold DO concurrently.
    await asyncio.gather(*(check(endpoint) for _ in range(8)))
    async with websockets.connect(endpoint, origin=origin, open_timeout=45) as ws:
        await ws.send(
            json.dumps(
                {
                    "type": "create_room",
                    "protocol": "robocon2027-v4",
                    "ruleset": "abu2027-v1.1-fixed-r5",
                    "nickname": "RuntimeTest",
                }
            )
        )
        joined = await receive(ws, "joined")
        assert joined["private"] and len(joined["room"]) == 6
        await receive(ws, "lobby")
        await ws.send(json.dumps({"type": "start_room"}))
        await receive(ws, "ready")
        snapshot = await receive(ws, "state")
        assert snapshot["state"]["mode"] == "online"
    # A fresh upgrade after the previous socket closes must still work.
    await check(endpoint)
    print("PASS: concurrent upgrades, private room, game snapshot and new connection")


if __name__ == "__main__":

    async def run():
        async with asyncio.timeout(90):
            await main(sys.argv[1])

    asyncio.run(run())
