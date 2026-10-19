"""HTTP readiness and transparent WebSocket forwarding to the Godot process."""

import asyncio, os, signal


async def forward(reader, writer):
    try:
        while chunk := await reader.read(65536):
            writer.write(chunk)
            await writer.drain()
    finally:
        writer.close()


async def main():
    port = int(os.environ.get("PORT", "9080"))
    game = await asyncio.create_subprocess_exec(
        os.environ.get("GODOT_BIN", "godot"),
        "--headless",
        "--path",
        os.getcwd(),
        "--",
        "--server",
    )

    async def request(reader, writer):
        upstream = None
        try:
            header = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 5)
            if len(header) > 8192:
                return
            if b"upgrade: websocket" not in header.lower():
                status = b"200 OK" if game.returncode is None else b"503 Unavailable"
                writer.write(
                    b"HTTP/1.1 "
                    + status
                    + b"\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"
                )
                await writer.drain()
                return
            remote, upstream = await asyncio.open_connection("127.0.0.1", port)
            upstream.write(header)
            await upstream.drain()
            await asyncio.gather(forward(reader, upstream), forward(remote, writer))
        except (
            ConnectionError,
            asyncio.IncompleteReadError,
            asyncio.LimitOverrunError,
            TimeoutError,
        ):
            pass
        finally:
            writer.close()
            if upstream:
                upstream.close()

    for attempt in range(100):
        try:
            _, probe = await asyncio.open_connection("127.0.0.1", port)
            probe.close()
            break
        except ConnectionError:
            if game.returncode is not None:
                raise RuntimeError("Godot exited during startup")
            await asyncio.sleep(0.1)
    else:
        game.terminate()
        raise RuntimeError("Godot did not listen")
    server = await asyncio.start_server(
        request, "0.0.0.0", int(os.environ.get("PROXY_PORT", "8080")), limit=8192
    )
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, game.terminate)
    async with server:
        await game.wait()
    if game.returncode:
        raise SystemExit(game.returncode)


asyncio.run(main())
