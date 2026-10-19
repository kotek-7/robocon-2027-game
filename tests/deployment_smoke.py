"""Verify Worker -> Container -> Godot without joining a production queue."""

import asyncio
import json
import sys
from urllib.parse import urlsplit

import websockets


async def check(endpoint):
    url = urlsplit(endpoint)
    origin = f"{'https' if url.scheme == 'wss' else 'http'}://{url.netloc}"
    async with websockets.connect(endpoint, origin=origin, open_timeout=45) as socket:
        # An unsupported protocol is rejected before allocating a queue seat.
        await socket.send(json.dumps({"type": "queue", "protocol": "deployment-probe"}))
        response = json.loads(await asyncio.wait_for(socket.recv(), timeout=10))
        assert response == {"type": "error", "text": "Reload to update"}, response


async def main():
    for attempt in range(6):
        try:
            for pool in ["1v1", "2v2", "room"]:
                separator = "&" if "?" in sys.argv[1] else "?"
                await check(f"{sys.argv[1]}{separator}pool={pool}")
            print("Public WebSocket and Godot protocol check passed")
            return
        except (OSError, TimeoutError, websockets.exceptions.WebSocketException):
            if attempt == 5:
                raise
            await asyncio.sleep(10)


if __name__ == "__main__":
    asyncio.run(main())
