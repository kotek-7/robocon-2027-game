# Deployment

Host: `robocon2027.kotek7.com`. GitHub repository: `kotek-7/robocon-2027-game` (private).

The `Test and deploy` GitHub Actions workflow is the deployment entry point. Pushes to `main` and manual workflow dispatch run the same checks and build. No application release is uploaded directly from the workstation. Godot downloads are version-pinned and verified against SHA-256 digests. npm dependencies use a committed lockfile.

## Cloudflare

Worker `robocon-2027-game` serves static Web assets. `/index.wasm` returns the compressed binary with `Content-Encoding: gzip`; the browser receives the original WebAssembly bytes. The custom domain supplies HTTPS and the client automatically connects to `/ws` on the same host.

Durable Object `ArenaServer` routes to one `basic` Cloudflare Container. The container runs the unchanged GDScript competition model. A small HTTP/WebSocket gateway provides readiness checks and forwards WebSocket bytes to Godot. Outbound Internet access is disabled at runtime. Idle containers sleep after ten minutes. Workers and Container usage follow the account's Cloudflare billing plan; this configuration does not create a new subscription.

The initial service has a single shared matchmaking pool, up to 32 concurrent matches and 128 connected peers. There is no skill ranking or geographic pool splitting. Container replacement interrupts current matches; match persistence and draining across deployments are not implemented.

`wrangler.jsonc` explicitly disables `workers.dev` and version URLs so releases use the custom domain. Version URLs are currently unsupported for Workers that implement Durable Objects/Containers; `preview_urls: false` also records the intended policy. Source-map uploads are enabled for readable Worker exception stacks. The `default` Container scheduling policy is explicit. The compatibility date is `2026-10-19` with `nodejs_compat`, following the current [Workers best practices](https://developers.cloudflare.com/workers/best-practices/workers-best-practices/).

References: [workers.dev routing](https://developers.cloudflare.com/workers/configuration/routing/workers-dev/), [version URLs](https://developers.cloudflare.com/workers/versions-and-deployments/version-urls/), [source maps](https://developers.cloudflare.com/workers/observability/source-maps/).

## Authentication

GitHub Actions uses the repository secret `CLOUDFLARE_API_TOKEN`. The token needs deployment permissions for Workers Scripts, Workers Routes/custom domains, Containers/Cloudchamber and the target account, plus zone read for `kotek7.com`. Keep token values out of Git, workflow output and build artifacts. Account and zone identifiers are not secrets. HTTPS keys are managed by Cloudflare.

## Verification

`npm run check:worker` generates binding/runtime types with `wrangler types`, type-checks the JavaScript handlers against them, then bundles a dry-run deployment. The generated declaration is ignored by Git and regenerated in CI; after changing bindings, run `npm run typecheck:worker`. Local `.dev.vars*` and `.env*` secrets are ignored.

CD runs rule boundary tests and real WebSocket matching/reconnection checks before export. After deployment it checks `/health` and compares the publicly served, decompressed WebAssembly with the built file. `/health` reports Worker availability; two-client matching separately verifies the container backend.

Infrastructure references: [Cloudflare Containers](https://developers.cloudflare.com/containers/get-started/), [WebSocket forwarding](https://developers.cloudflare.com/containers/examples/websocket/), [static asset limits](https://developers.cloudflare.com/workers/platform/limits/).

## Configuration review — 2026-10-19

Reviewed the Worker, Containers binding/lifecycle, Docker build inputs, static asset packaging and CD against current official documentation.

- `ArenaServer` is declared in `exports` with SQLite storage, replacing the historical `v1` / `new_sqlite_classes` declaration. Class name, storage backend, binding and `casual-v2` object name stay the same, so the documented migration adopts the existing namespace. Do not add `migrations` alongside `exports`. After the first deployment with `exports`, future deploys cannot use the old migration-array configuration; a source rollback must retain `exports`. See [class export migration](https://developers.cloudflare.com/durable-objects/reference/durable-objects-migrations/#migrate-from-the-legacy-migrations-flow).
- Keep the `default` Container scheduling policy: the official [selection guide](https://developers.cloudflare.com/containers/configuration/scheduling-policy/) assigns it to services sharing one image and instance size. The beta `durable_object` policy is intended for per-instance configuration, and adopting it requires a replacement application/namespace. It is not a routine upgrade for this matchmaking service.
- `sleepAfter` is inactivity time, not a maximum match duration. The pinned helper tracks active WebSockets and renews activity. Keep the shared instance limit of one to preserve the single matchmaking pool.
- Docker must copy `scenes/`, `resources/` and `default_bus_layout.tres` as well as scripts/assets: even headless startup loads the main scene and its resources before entering server mode.
- CDN packaging rebuilds its output directory and checks the 25 MiB per-file limit explicitly. HTML revalidates at both `/` and `/index.html`. CI clears the Web export before packaging. See [asset limits](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/) and [asset headers](https://developers.cloudflare.com/workers/static-assets/headers/).
- `/index.wasm` ignores byte ranges of the stored gzip file and returns a complete gzip representation. It preserves conditional GET/HEAD status and validators; `encodeBody: "manual"` prevents double compression. See [Response API](https://developers.cloudflare.com/workers/runtime-apis/response/).
- Slow receivers do not accumulate additional state snapshots while the Godot WebSocket has pending outbound data. The next broadcast supplies current state; control messages retain ordered delivery.
- Worker HTTP regression tests run with `npm run test:worker`. CD tests private rooms through the built container and probes the public WebSocket with an unsupported protocol, verifying Godot responds without entering a public matchmaking queue.
- `/health` is Worker liveness only. The public WebSocket probe verifies backend reachability, not the deployed image revision. `wrangler deploy` starts a rollout; it does not prove all instances have finished replacing. Worker activation and image rollout are not atomic. Matches remain in memory and are interrupted on replacement. See [rollouts](https://developers.cloudflare.com/containers/configuration/rollouts/).

Local review validation passed: 7 Worker HTTP tests, Wrangler 4.151.1 dry-run, workerd gzip/HEAD check, stale-file removal and gzip byte equality, and 69 Godot rule checks. Import/startup from the Docker file set and gateway readiness/shutdown passed. Matchmaking, private rooms, network reconnect/forfeit, 2v2 and CPU-partner suites plus the deployment probe passed through the local gateway; after the snapshot change, the outbound-buffer overflow no longer appeared in those suites. Docker itself could not run locally (Desktop socket unavailable; system socket permission denied). The CI Docker build and production rollout remain unverified; no deployment was performed during this review.
