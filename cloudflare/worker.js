import { DurableObject } from "cloudflare:workers";

const INACTIVITY_TIMEOUT_MS = 60 * 1000;
const STARTUP_TIMEOUT_MS = 30_000;

/** @extends {DurableObject<Env>} */
export class ArenaServer extends DurableObject {
	/** @type {Promise<void> | undefined} */
	#starting;

	/** @param {DurableObjectState} ctx @param {Env} env */
	constructor(ctx, env) {
		super(ctx, env);
		// The timeout belongs to this DO incarnation, not the container process.
		const container = ctx.container;
		void ctx.blockConcurrencyWhile(async () => {
			// The former helper stored sleep alarms. This implementation has none.
			await ctx.storage.deleteAlarm();
			if (container?.running)
				await container.setInactivityTimeout(INACTIVITY_TIMEOUT_MS);
		});
	}

	/** @param {Request} request */
	async fetch(request) {
		try {
			// A caller's cancellation must not cancel startup for other players.
			this.#starting ??= this.#startAndWaitForReady().finally(() => {
				this.#starting = undefined;
			});
			await this.#starting;
			const url = new URL(request.url);
			url.protocol = "http:";
			url.host = "container";
			const forwarded = new Request(url, request);
			forwarded.headers.delete("host");
			// Preserve the upgrade and let workerd proxy the socket directly.
			const container = this.ctx.container;
			if (!container) throw new Error("Arena container binding is missing");
			return await container.getTcpPort(8080).fetch(forwarded);
		} catch (error) {
			console.error("Arena container unavailable", error);
			return new Response("Game server temporarily unavailable", {
				status: 503,
				headers: { "Retry-After": "2", "Cache-Control": "no-store" },
			});
		}
	}

	async #startAndWaitForReady() {
		const container = this.ctx.container;
		if (!container) throw new Error("Arena container binding is missing");
		const deadline = Date.now() + STARTUP_TIMEOUT_MS;
		let lastError;
		while (Date.now() < deadline) {
			try {
				// default policy: image, size and rollouts are configured in Wrangler.
				// Allocation can fail transiently while a previous instance stops.
				if (!container.running) container.start({ enableInternet: false });
				await container.setInactivityTimeout(INACTIVITY_TIMEOUT_MS);
				const response = await container.getTcpPort(8080).fetch(
					"http://container/health",
					{ signal: AbortSignal.timeout(1000) },
				);
				await response.body?.cancel();
				if (!response.ok) throw new Error(`Readiness returned ${response.status}`);
				return;
			} catch (error) {
				lastError = error;
				await scheduler.wait(200);
			}
		}
		throw new Error("Arena did not become ready within 30 seconds", { cause: lastError });
	}
}

export { default } from "./handler.js";
