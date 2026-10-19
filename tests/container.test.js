import assert from "node:assert/strict";
import { registerHooks } from "node:module";
import test from "node:test";

// Exercise the production class with a fake platform binding. Runtime WebSocket
// forwarding is exercised separately by the Wrangler/Docker CI smoke test.
// Platform inactivity timing still requires a deployed environment.
const hooks = registerHooks({
	resolve(specifier, context, next) {
		if (specifier === "cloudflare:workers") return { url: "test:workers", shortCircuit: true };
		return next(specifier, context);
	},
	load(url, context, next) {
		if (url === "test:workers") return {
			format: "module", shortCircuit: true,
			source: "export class DurableObject { constructor(ctx, env) { this.ctx = ctx; this.env = env; } }",
		};
		return next(url, context);
	},
});
const { ArenaServer } = await import("../cloudflare/worker.js");
hooks.deregister();

async function fixture({ running = false, health = async () => new Response("ok"), forward } = {}) {
	const state = { starts: [], timeouts: [], forwarded: [], probes: 0, blocks: [], deletedAlarms: 0 };
	const container = {
		running,
		start(options) { this.running = true; state.starts.push(options); },
		async setInactivityTimeout(ms) { state.timeouts.push(ms); },
		getTcpPort(port) {
			assert.equal(port, 8080);
			return { async fetch(request, options) {
				if (typeof request === "string") {
					assert.equal(request, "http://container/health");
					assert.ok(options.signal instanceof AbortSignal);
					state.probes++;
					return health();
				}
				state.forwarded.push(request);
				return forward ? forward(request) : new Response("forwarded");
			} };
		},
	};
	const ctx = {
		container,
		storage: { async deleteAlarm() { state.deletedAlarms++; } },
		blockConcurrencyWhile(fn) { const work = fn(); state.blocks.push(work); return work; },
	};
	const arena = new ArenaServer(ctx, {});
	await Promise.all(state.blocks);
	return { arena, container, state };
}
const request = () => new Request("https://arena.example/ws?room=abc", {
	headers: { Upgrade: "websocket", Host: "arena.example", Origin: "https://arena.example" },
});

function fakeTime(t) {
	let now = 0;
	t.mock.method(Date, "now", () => now);
	globalThis.scheduler = { async wait(ms) { now += ms; } };
	t.after(() => { delete globalThis.scheduler; });
	t.mock.method(console, "error", () => {});
}

test("concurrent upgrades share startup and readiness, preserve the response", async () => {
	const ready = Promise.withResolvers();
	const sentinel = { webSocket: {}, status: 101 };
	const { arena, state } = await fixture({ health: () => ready.promise, forward: () => sentinel });
	const first = arena.fetch(request());
	const second = arena.fetch(request());
	await Promise.resolve();
	assert.equal(state.probes, 1);
	assert.equal(state.forwarded.length, 0);
	ready.resolve(new Response("ready"));
	assert.deepEqual(await Promise.all([first, second]), [sentinel, sentinel]);
	assert.deepEqual(state.starts, [{ enableInternet: false }]);
	assert.deepEqual(state.timeouts, [600_000]);
	for (const forwarded of state.forwarded) {
		assert.equal(forwarded.url, "http://container/ws?room=abc");
		assert.equal(forwarded.headers.get("Host"), null);
		assert.equal(forwarded.headers.get("Origin"), "https://arena.example");
		assert.equal(forwarded.headers.get("Upgrade"), "websocket");
	}
});

test("a reconstructed DO restores inactivity without restarting its container", async () => {
	const { arena, state } = await fixture({ running: true });
	await Promise.all(state.blocks);
	assert.equal(state.deletedAlarms, 1);
	assert.deepEqual(state.timeouts, [600_000]);
	assert.equal((await arena.fetch(request())).status, 200);
	assert.equal(state.starts.length, 0);
});

test("503 readiness is retried, with response streams cancelled", async (t) => {
	fakeTime(t);
	let attempts = 0, cancelled = 0;
	const { arena, state } = await fixture({ health: async () => {
		attempts++;
		return new Response(new ReadableStream({ cancel() { cancelled++; } }), { status: attempts === 1 ? 503 : 200 });
	} });
	assert.equal((await arena.fetch(request())).status, 200);
	assert.equal(state.probes, 2);
	assert.equal(cancelled, 2);
});

test("temporary allocation failure retries before probing ports", async (t) => {
	fakeTime(t);
	const { arena, container, state } = await fixture();
	const start = container.start.bind(container);
	let attempts = 0;
	container.start = (options) => { if (++attempts === 1) throw new Error("still stopping"); start(options); };
	assert.equal((await arena.fetch(request())).status, 200);
	assert.equal(attempts, 2);
	assert.equal(state.probes, 1);
});

test("failed startup is bounded and the next request can recover", async (t) => {
	fakeTime(t);
	let broken = true;
	const { arena, state } = await fixture({ health: async () => {
		if (broken) throw new Error("port unavailable");
		return new Response("ok");
	} });
	const failure = await arena.fetch(request());
	assert.equal(failure.status, 503);
	assert.equal(failure.headers.get("Retry-After"), "2");
	assert.equal(state.forwarded.length, 0);
	assert.equal(Date.now(), 30_000);
	broken = false;
	assert.equal((await arena.fetch(request())).status, 200);
});

test("container exit between requests triggers fresh startup", async () => {
	const { arena, container, state } = await fixture();
	await arena.fetch(request());
	container.running = false;
	await arena.fetch(request());
	assert.equal(state.starts.length, 2);
	assert.equal(state.probes, 2);
});

test("forwarding failure is not replayed and does not poison the next request", async (t) => {
	fakeTime(t);
	let attempts = 0;
	const { arena } = await fixture({ forward: () => {
		if (++attempts === 1) throw new Error("connection lost");
		return new Response("ok");
	} });
	assert.equal((await arena.fetch(request())).status, 503);
	assert.equal(attempts, 1);
	assert.equal((await arena.fetch(request())).status, 200);
});

test("cancelling one caller does not cancel shared startup", async (t) => {
	fakeTime(t);
	const ready = Promise.withResolvers();
	const { arena, state } = await fixture({
		health: () => ready.promise,
		forward: (forwarded) => {
			forwarded.signal.throwIfAborted();
			return new Response("ok");
		},
	});
	const controller = new AbortController();
	const first = arena.fetch(new Request(request(), { signal: controller.signal }));
	const second = arena.fetch(request());
	controller.abort();
	ready.resolve(new Response("ready"));
	assert.equal((await first).status, 503);
	assert.equal((await second).status, 200);
	assert.equal(state.starts.length, 1);
});
