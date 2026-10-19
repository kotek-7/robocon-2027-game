// Provision with `wrangler secret put GAME_ORIGIN_KEY`; never commit the value.
interface Env {
	GAME_ORIGIN_KEY: string;
}
