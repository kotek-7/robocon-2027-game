"""Bounded HTTP/WebSocket gateway and supervisor for the Godot process."""

import asyncio
import contextlib
import os
import signal


async def close(writer):
    writer.close()
    with contextlib.suppress(ConnectionError):
        await writer.wait_closed()


async def forward(reader, writer):
    while chunk := await reader.read(65536):
        writer.write(chunk)
        await writer.drain()


async def respond(writer, status, *, head=False, extra=b""):
    body = status.split(b" ", 1)[1] + b"\n"
    writer.write(
        b"HTTP/1.1 " + status + b"\r\nContent-Type: text/plain\r\n"
        b"Cache-Control: no-store\r\nConnection: close\r\nContent-Length: "
        + str(len(body)).encode()
        + b"\r\n"
        + extra
        + b"\r\n"
        + (b"" if head else body)
    )
    await writer.drain()


async def request(reader, writer, game, port):
    upstream = None
    pumps = []
    try:
        header = await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 5)
        if len(header) > 8192:
            await respond(writer, b"431 Request Header Fields Too Large")
            return
        try:
            lines = header.decode("ascii").split("\r\n")
            method, target, version = lines[0].split(" ")
            if (
                version != "HTTP/1.1"
                or not target.startswith("/")
                or target.startswith("//")
            ):
                raise ValueError("Invalid request line")
            headers = {}
            for line in lines[1:-2]:
                name, value = line.split(":", 1)
                if not name or name != name.strip() or name.lower() in headers:
                    raise ValueError("Invalid or duplicate header")
                headers[name.lower()] = value.strip().lower()
        except (ValueError, UnicodeError):
            await respond(writer, b"400 Bad Request")
            return
        if method not in ("GET", "HEAD"):
            await respond(
                writer, b"405 Method Not Allowed", extra=b"Allow: GET, HEAD\r\n"
            )
            return
        if "transfer-encoding" in headers or headers.get("content-length", "0") != "0":
            await respond(writer, b"400 Bad Request", head=method == "HEAD")
            return
        path = target.partition("?")[0]
        if path == "/health":
            await respond(
                writer,
                b"200 OK" if game.returncode is None else b"503 Service Unavailable",
                head=method == "HEAD",
            )
            return
        # '/' remains supported by the local integration clients.
        if path not in ("/", "/ws"):
            await respond(writer, b"404 Not Found", head=method == "HEAD")
            return
        connection = {
            token.strip() for token in headers.get("connection", "").split(",")
        }
        if (
            method != "GET"
            or headers.get("upgrade") != "websocket"
            or "upgrade" not in connection
        ):
            await respond(
                writer,
                b"426 Upgrade Required",
                head=method == "HEAD",
                extra=b"Upgrade: websocket\r\n",
            )
            return
        remote, upstream = await asyncio.wait_for(
            asyncio.open_connection("127.0.0.1", port), 5
        )
        upstream.write(header)
        await upstream.drain()
        pumps = [
            asyncio.create_task(forward(reader, upstream)),
            asyncio.create_task(forward(remote, writer)),
        ]
        # A disconnected side must not leave the other pump waiting indefinitely.
        done, _ = await asyncio.wait(pumps, return_when=asyncio.FIRST_COMPLETED)
        for task in done:
            task.result()
    except asyncio.LimitOverrunError:
        await respond(writer, b"431 Request Header Fields Too Large")
    except (ConnectionError, asyncio.IncompleteReadError, TimeoutError):
        pass
    finally:
        for task in pumps:
            task.cancel()
        await asyncio.gather(*pumps, return_exceptions=True)
        await close(writer)
        if upstream:
            await close(upstream)


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
    loop = asyncio.get_running_loop()
    stopping = asyncio.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stopping.set)
    server = None
    clients = set()

    async def accept(reader, writer):
        task = asyncio.current_task()
        clients.add(task)
        try:
            await request(reader, writer, game, port)
        finally:
            clients.discard(task)

    exited = asyncio.create_task(game.wait())
    stopped = asyncio.create_task(stopping.wait())
    try:
        for _ in range(100):
            if stopping.is_set():
                return
            if game.returncode is not None:
                raise RuntimeError("Godot exited during startup")
            try:
                _, probe = await asyncio.wait_for(
                    asyncio.open_connection("127.0.0.1", port), 0.1
                )
                await close(probe)
                break
            except (ConnectionError, TimeoutError):
                await asyncio.sleep(0.1)
        else:
            raise RuntimeError("Godot did not listen")
        # Bind only after Godot is listening: Container port probes cannot race startup.
        server = await asyncio.start_server(
            accept, "0.0.0.0", int(os.environ.get("PROXY_PORT", "8080")), limit=8192
        )
        await asyncio.wait((exited, stopped), return_when=asyncio.FIRST_COMPLETED)
        if not stopping.is_set():
            raise RuntimeError(f"Godot exited unexpectedly: {game.returncode}")
    finally:
        if server:
            server.close()
            await server.wait_closed()
        for task in list(clients):
            task.cancel()
        await asyncio.gather(*clients, return_exceptions=True)
        if game.returncode is None:
            with contextlib.suppress(ProcessLookupError):
                game.terminate()
            try:
                await asyncio.wait_for(asyncio.shield(exited), 5)
            except TimeoutError:
                with contextlib.suppress(ProcessLookupError):
                    game.kill()
        await exited
        stopped.cancel()
        await asyncio.gather(stopped, return_exceptions=True)
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.remove_signal_handler(sig)


if __name__ == "__main__":
    asyncio.run(main())
