import { DurableObject } from "cloudflare:workers";

// Compatibility export for the retired namespace. There is no ARENA binding,
// Container application, startup path, or routing to this class.
export class ArenaServer extends DurableObject {
	fetch() {
		return new Response("Game server moved to OCI", { status: 410 });
	}
	async alarm() {
		await this.ctx.storage.deleteAlarm();
	}
}

export { default } from "./handler.js";
