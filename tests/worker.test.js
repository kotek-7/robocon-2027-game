import assert from "node:assert/strict";
import test from "node:test";
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

test("WebSocket preserves the container response and single matchmaking identity", async () => {
	const sentinel = {};
	const request = new Request(`${origin}/ws`, {
		headers: { Upgrade: "websocket", Origin: origin },
	});
	const result = await worker.fetch(request, {
		ARENA: {
			getByName: (name) => {
				assert.equal(name, "casual-v2");
				return {
					fetch: (forwarded) => {
						assert.equal(forwarded, request);
						return sentinel;
					},
				};
			},
		},
	});
	assert.equal(result, sentinel);
});

test("health does not start a container and ordinary assets pass through", async () => {
	assert.equal(
		(await worker.fetch(new Request(`${origin}/health`), {})).status,
		200,
	);
	const sentinel = new Response("asset");
	assert.equal(
		await worker.fetch(new Request(`${origin}/index.js`), {
			ASSETS: { fetch: () => sentinel },
		}),
		sentinel,
	);
});
