import assert from "node:assert/strict";
import test, { mock } from "node:test";
import worker from "../cloudflare/handler.js";

const origin = "https://arena.example";

test("Wasm ranges fetch a complete gzip representation and preserve bytes", async () => {
	const bytes = new Uint8Array([31, 139, 8, 0]);
	const response = await worker.fetch(
		new Request(`${origin}/index.wasm`, {
			headers: { Range: "bytes=0-1", "If-Range": '"old"' },
		}),
		{
			ASSETS: {
				fetch: async (request) => {
					assert.equal(new URL(request.url).pathname, "/index.wasm.gz");
					assert.equal(request.headers.get("Range"), null);
					assert.equal(request.headers.get("If-Range"), null);
					return new Response(bytes, {
						headers: { ETag: '"gzip"', "Accept-Ranges": "bytes" },
					});
				},
			},
		},
	);
	assert.equal(response.status, 200);
	assert.equal(response.headers.get("Content-Encoding"), "gzip");
	assert.equal(response.headers.get("Content-Type"), "application/wasm");
	assert.equal(response.headers.get("Accept-Ranges"), null);
	assert.deepEqual(new Uint8Array(await response.arrayBuffer()), bytes);
});

for (const method of ["GET", "HEAD"]) {
	test(`Wasm ${method} preserves conditional 304 and cache metadata`, async () => {
		const response = await worker.fetch(
			new Request(`${origin}/index.wasm`, {
				method,
				headers: { "If-None-Match": '"gzip"' },
			}),
			{
				ASSETS: {
					fetch: async (request) => {
						assert.equal(request.method, method);
						assert.equal(request.headers.get("If-None-Match"), '"gzip"');
						return new Response(null, {
							status: 304,
							headers: { ETag: '"gzip"' },
						});
					},
				},
			},
		);
		assert.equal(response.status, 304);
		assert.equal(response.body, null);
		assert.equal(
			response.headers.get("Cache-Control"),
			"public, max-age=0, must-revalidate",
		);
		assert.equal(response.headers.get("ETag"), '"gzip"');
	});
}

test("asset errors remain errors", async () => {
	const response = await worker.fetch(new Request(`${origin}/index.wasm`), {
		ASSETS: { fetch: async () => new Response("missing", { status: 404 }) },
	});
	assert.equal(response.status, 404);
	assert.equal(response.headers.get("Content-Encoding"), null);
});

test("WebSocket rejects non-upgrades and foreign origins before accessing container", async () => {
	assert.equal(
		(await worker.fetch(new Request(`${origin}/ws`), {})).status,
		426,
	);
	assert.equal(
		(
			await worker.fetch(
				new Request(`${origin}/ws`, {
					headers: { Upgrade: "websocket", Origin: "https://foreign.example" },
				}),
				{},
			)
		).status,
		403,
	);
});

const env = {
	GAME_ORIGIN: "https://backend.example",
	GAME_ORIGIN_KEY: "test-secret",
};

test("WebSocket forwards to OCI preserving the upgrade and overriding credentials", async () => {
	const sentinel = {};
	const spy = mock.method(globalThis, "fetch", async (request) => {
		assert.equal(request.url, "https://backend.example/ws?pool=1v1");
		assert.equal(request.headers.get("Upgrade"), "websocket");
		assert.equal(request.headers.get("X-Arena-Key"), "test-secret");
		return sentinel;
	});
	try {
		const result = await worker.fetch(
			new Request(`${origin}/ws?pool=1v1`, {
				headers: {
					Upgrade: "websocket",
					Origin: origin,
					"X-Arena-Key": "spoof",
				},
			}),
			env,
		);
		assert.equal(result, sentinel);
	} finally {
		spy.mock.restore();
	}
});

test("ordinary assets pass through", async () => {
	const sentinel = new Response("asset");
	assert.equal(
		await worker.fetch(new Request(`${origin}/index.js`), {
			ASSETS: { fetch: () => sentinel },
		}),
		sentinel,
	);
});

for (const path of ["/ws", "/health", "/index.wasm"]) {
	test(`${path} rejects POST without touching bindings`, async () => {
		const response = await worker.fetch(
			new Request(`${origin}${path}`, { method: "POST" }),
			{},
		);
		assert.equal(response.status, 405);
		assert.equal(
			response.headers.get("Allow"),
			path === "/ws" ? "GET" : "GET, HEAD",
		);
	});
}

test("health reflects backend failure, never caches, and HEAD has no body", async () => {
	for (const status of [200, 503, 403]) {
		const spy = mock.method(globalThis, "fetch", async (url, options) => {
			assert.equal(url, "https://backend.example/health");
			assert.equal(options.headers["X-Arena-Key"], "test-secret");
			return new Response("health", { status });
		});
		try {
			for (const method of ["GET", "HEAD"]) {
				const response = await worker.fetch(
					new Request(`${origin}/health`, { method }),
					env,
				);
				assert.equal(response.status, status === 200 ? 200 : 503);
				assert.equal(response.headers.get("Cache-Control"), "no-store");
				if (method === "HEAD") assert.equal(response.body, null);
			}
		} finally {
			spy.mock.restore();
		}
	}
	const spy = mock.method(globalThis, "fetch", async () => {
		throw new Error("offline");
	});
	try {
		assert.equal(
			(await worker.fetch(new Request(`${origin}/health`), env)).status,
			503,
		);
	} finally {
		spy.mock.restore();
	}
});

test("arbitrary pool names cannot allocate additional containers", async () => {
	for (const pool of ["random", "__proto__", "constructor", ""]) {
		const response = await worker.fetch(
			new Request(`${origin}/ws?pool=${pool}`, {
				headers: { Upgrade: "websocket", Origin: origin },
			}),
			{},
		);
		assert.equal(response.status, 400);
	}
});
