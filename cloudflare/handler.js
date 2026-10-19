export default {
	/** @param {Request} request @param {Env} env */
	async fetch(request, env) {
		const url = new URL(request.url);
		if (["/health", "/index.wasm", "/ws"].includes(url.pathname)) {
			const allow = url.pathname === "/ws" ? "GET" : "GET, HEAD";
			if (
				request.method !== "GET" &&
				!(request.method === "HEAD" && url.pathname !== "/ws")
			)
				return new Response("Method not allowed", {
					status: 405,
					headers: { Allow: allow, "Cache-Control": "no-store" },
				});
		}
		if (url.pathname === "/health") {
			try {
				const upstream = await fetch(`${env.GAME_ORIGIN}/health`, {
					headers: { "X-Arena-Key": env.GAME_ORIGIN_KEY },
					signal: AbortSignal.timeout(5000),
				});
				const health = Response.json(
					{
						status: upstream.ok ? "ok" : "unavailable",
						protocol: "robocon2027-v4",
						backend: "oci",
					},
					{
						status: upstream.ok ? 200 : 503,
						headers: { "Cache-Control": "no-store" },
					},
				);
				return request.method === "HEAD" ? new Response(null, health) : health;
			} catch {
				return new Response(
					request.method === "HEAD" ? null : "Backend unavailable",
					{
						status: 503,
						headers: { "Cache-Control": "no-store" },
					},
				);
			}
		}
		if (url.pathname === "/ws") {
			if (request.headers.get("Upgrade")?.toLowerCase() !== "websocket")
				return new Response("WebSocket required", {
					status: 426,
					headers: { Upgrade: "websocket" },
				});
			const origin = request.headers.get("Origin");
			if (origin && origin !== url.origin)
				return new Response("Origin rejected", { status: 403 });
			// Retain mode URLs for existing clients, but all modes share one process.
			const pool = url.searchParams.get("pool") ?? "room";
			if (!["1v1", "2v2", "room"].includes(pool))
				return new Response("Unknown matchmaking pool", { status: 400 });
			const target = new URL(request.url);
			target.protocol = new URL(env.GAME_ORIGIN).protocol;
			target.host = new URL(env.GAME_ORIGIN).host;
			const forwarded = new Request(target, request);
			forwarded.headers.set("X-Arena-Key", env.GAME_ORIGIN_KEY);
			return fetch(forwarded);
		}
		if (url.pathname === "/index.wasm") {
			url.pathname = "/index.wasm.gz";
			// A byte range of the stored gzip file is not a standalone Wasm body.
			// Serve a complete representation; retain conditional GET and HEAD.
			const forwarded = new Request(url, request);
			forwarded.headers.delete("Range");
			forwarded.headers.delete("If-Range");
			const asset = await env.ASSETS.fetch(forwarded);
			if (!asset.ok && asset.status !== 304) return asset;
			const headers = new Headers(asset.headers);
			headers.delete("Accept-Ranges");
			headers.set("Content-Type", "application/wasm");
			headers.set("Content-Encoding", "gzip");
			headers.set("Cache-Control", "public, max-age=0, must-revalidate");
			return new Response(asset.body, {
				status: asset.status,
				statusText: asset.statusText,
				headers,
				encodeBody: "manual",
			});
		}
		return env.ASSETS.fetch(request);
	},
};
