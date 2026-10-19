"""Real TCP boundary tests; process tests use a deliberately uncooperative child."""

import asyncio
import os
import signal
import socket
import tempfile
import unittest
from unittest.mock import patch
from pathlib import Path
from types import SimpleNamespace

from cloudflare.server import request


class GatewayTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.game = SimpleNamespace(returncode=None)
        self.upstream_headers = []
        self.upstream_closed = asyncio.Event()

        async def echo(reader, writer):
            try:
                header = await reader.readuntil(b"\r\n\r\n")
                self.upstream_headers.append(header)
                writer.write(
                    b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
                )
                await writer.drain()
                while data := await reader.read(1024):
                    writer.write(data)
                    await writer.drain()
            finally:
                writer.close()
                await writer.wait_closed()
                self.upstream_closed.set()

        self.backend = await asyncio.start_server(echo, "127.0.0.1", 0)
        port = self.backend.sockets[0].getsockname()[1]
        self.gateway = await asyncio.start_server(
            lambda r, w: request(r, w, self.game, port), "127.0.0.1", 0, limit=8192
        )
        self.port = self.gateway.sockets[0].getsockname()[1]

    async def asyncTearDown(self):
        self.gateway.close()
        self.backend.close()
        await self.gateway.wait_closed()
        await self.backend.wait_closed()

    async def exchange(self, raw):
        reader, writer = await asyncio.open_connection("127.0.0.1", self.port)
        writer.write(raw)
        await writer.drain()
        result = await asyncio.wait_for(reader.read(), 2)
        writer.close()
        await writer.wait_closed()
        return result

    async def test_origin_key_required_when_configured(self):
        with patch.dict(os.environ, {"GAME_ORIGIN_KEY": "abc123"}):
            for key in (b"", b"X-Arena-Key: wrong\r\n"):
                result = await self.exchange(b"GET /health HTTP/1.1\r\n" + key + b"\r\n")
                self.assertIn(b"403 Forbidden", result)
            result = await self.exchange(b"GET /health HTTP/1.1\r\nX-Arena-Key: abc123\r\n\r\n")
            self.assertIn(b"200 OK", result)

    async def test_health_and_head(self):
        for method in (b"GET", b"HEAD"):
            result = await self.exchange(
                method + b" /health HTTP/1.1\r\nHost: localhost\r\n\r\n"
            )
            self.assertIn(b"200 OK", result)
            self.assertIn(b"Cache-Control: no-store", result)
            if method == b"HEAD":
                self.assertTrue(result.endswith(b"\r\n\r\n"))
        self.game.returncode = 1
        self.assertIn(
            b"503 Service Unavailable",
            await self.exchange(b"GET /health HTTP/1.1\r\n\r\n"),
        )
        self.assertFalse(self.upstream_headers)

    async def test_rejects_invalid_routes_methods_and_spoofed_upgrades(self):
        cases = [
            (b"POST /ws HTTP/1.1\r\n\r\n", b"405"),
            (b"GET /missing HTTP/1.1\r\n\r\n", b"404"),
            (b"GET /ws HTTP/1.1\r\nX-Upgrade: websocket\r\n\r\n", b"426"),
            (b"GET /ws HTTP/1.1\r\nUpgrade: websocket\r\n\r\n", b"426"),
            (
                b"GET /ws HTTP/1.1\r\nUpgrade: websocket\r\nUpgrade: other\r\n\r\n",
                b"400",
            ),
            (b"GET /health HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n", b"400"),
            (b"invalid\r\n\r\n", b"400"),
            (b"GET /health HTTP/1.1\r\nX: " + b"a" * 9000 + b"\r\n\r\n", b"431"),
        ]
        for raw, status in cases:
            with self.subTest(raw=raw[:80]):
                self.assertTrue(
                    (await self.exchange(raw)).startswith(b"HTTP/1.1 " + status)
                )
        self.assertFalse(self.upstream_headers)

    async def test_upgrade_bytes_and_disconnect_propagate(self):
        reader, writer = await asyncio.open_connection("127.0.0.1", self.port)
        header = b"GET /ws?room=test HTTP/1.1\r\nUpgrade:websocket\r\nConnection: keep-alive, Upgrade\r\n\r\n"
        writer.write(header)
        await writer.drain()
        self.assertIn(
            b"101 Switching Protocols",
            await asyncio.wait_for(reader.readuntil(b"\r\n\r\n"), 2),
        )
        payload = bytes(range(256))
        writer.write(payload)
        await writer.drain()
        self.assertEqual(
            await asyncio.wait_for(reader.readexactly(len(payload)), 2), payload
        )
        self.assertEqual(self.upstream_headers, [header])
        writer.close()
        await writer.wait_closed()
        await asyncio.wait_for(self.upstream_closed.wait(), 2)


class SupervisorTests(unittest.IsolatedAsyncioTestCase):
    async def test_signal_during_startup_reaps_child_even_when_it_ignores_term(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "godot"
            pidfile = Path(directory) / "pid"
            fixture.write_text(
                "#!/usr/bin/env python3\nimport os, signal, time\nsignal.signal(signal.SIGTERM, signal.SIG_IGN)\nopen(os.environ['TEST_PID_FILE'], 'w').write(str(os.getpid()))\ntime.sleep(60)\n"
            )
            fixture.chmod(0o755)
            # Occupy a port without listening so no unrelated service passes readiness.
            with socket.socket() as reserved:
                reserved.bind(("127.0.0.1", 0))
                process = await asyncio.create_subprocess_exec(
                    "python3",
                    "cloudflare/server.py",
                    env={
                        **os.environ,
                        "GODOT_BIN": str(fixture),
                        "TEST_PID_FILE": str(pidfile),
                        "PORT": str(reserved.getsockname()[1]),
                    },
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
                child = None
                try:
                    for _ in range(100):
                        if pidfile.exists():
                            child = int(pidfile.read_text())
                            break
                        await asyncio.sleep(0.02)
                    self.assertIsNotNone(child)
                    process.send_signal(signal.SIGTERM)
                    _, stderr = await asyncio.wait_for(process.communicate(), 8)
                    self.assertEqual(process.returncode, 0, stderr.decode())
                    with self.assertRaises(ProcessLookupError):
                        os.kill(child, 0)
                finally:
                    if process.returncode is None:
                        process.kill()
                        await process.wait()
                    if child:
                        try:
                            os.kill(child, signal.SIGKILL)
                        except ProcessLookupError:
                            pass

    async def test_bind_failure_reaps_started_child(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "godot"
            pidfile = Path(directory) / "pid"
            fixture.write_text(
                "#!/usr/bin/env python3\nimport os, socket, time\n"
                "s=socket.socket(); s.bind(('127.0.0.1', int(os.environ['PORT']))); s.listen()\n"
                "open(os.environ['TEST_PID_FILE'], 'w').write(str(os.getpid()))\n"
                "time.sleep(60)\n"
            )
            fixture.chmod(0o755)
            with socket.socket() as backend, socket.socket() as occupied:
                backend.bind(("127.0.0.1", 0))
                port = backend.getsockname()[1]
                backend.close()
                occupied.bind(("127.0.0.1", 0))
                occupied.listen()
                process = await asyncio.create_subprocess_exec(
                    "python3",
                    "cloudflare/server.py",
                    env={
                        **os.environ,
                        "GODOT_BIN": str(fixture),
                        "TEST_PID_FILE": str(pidfile),
                        "PORT": str(port),
                        "PROXY_PORT": str(occupied.getsockname()[1]),
                    },
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                )
                try:
                    _, stderr = await asyncio.wait_for(process.communicate(), 8)
                    self.assertNotEqual(process.returncode, 0)
                    self.assertIn(b"address already in use", stderr.lower())
                    self.assertTrue(pidfile.exists())
                    with self.assertRaises(ProcessLookupError):
                        os.kill(int(pidfile.read_text()), 0)
                finally:
                    if process.returncode is None:
                        process.kill()
                        await process.wait()
                    if pidfile.exists():
                        try:
                            os.kill(int(pidfile.read_text()), signal.SIGKILL)
                        except ProcessLookupError:
                            pass


if __name__ == "__main__":
    unittest.main()
