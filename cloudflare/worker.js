import { Container } from "@cloudflare/containers";

export class ArenaServer extends Container {
	defaultPort = 8080;
	sleepAfter = "10m";
	enableInternet = false;
}

export { default } from "./handler.js";
