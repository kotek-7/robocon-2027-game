# Deployment

Host: `robocon2027.kotek7.com`. GitHub repository: `kotek-7/robocon-2027-game` (private).

The `Test and deploy` GitHub Actions workflow is the deployment entry point. Pushes to `main` and manual workflow dispatch run the same checks and build. No application release is uploaded directly from the workstation. Godot downloads are version-pinned and verified against SHA-256 digests. npm dependencies use a committed lockfile.

## Cloudflare

Worker `robocon-2027-game` serves static Web assets. `/index.wasm` returns the compressed binary with `Content-Encoding: gzip`; the browser receives the original WebAssembly bytes. The custom domain supplies HTTPS and the client automatically connects to `/ws` on the same host.

Durable Object `ArenaServer` routes to one `basic` Cloudflare Container. The container runs the unchanged GDScript competition model. A small HTTP/WebSocket gateway provides readiness checks and forwards WebSocket bytes to Godot. Outbound Internet access is disabled at runtime. Idle containers sleep after ten minutes. Workers and Container usage follow the account's Cloudflare billing plan; this configuration does not create a new subscription.

The initial service has a single shared matchmaking pool, up to 32 concurrent matches and 128 connected peers. There is no skill ranking or geographic pool splitting. Container replacement interrupts current matches; match persistence and draining across deployments are not implemented.

## Authentication

GitHub Actions uses the repository secret `CLOUDFLARE_API_TOKEN`. The token needs deployment permissions for Workers Scripts, Workers Routes/custom domains, Containers/Cloudchamber and the target account, plus zone read for `kotek7.com`. Keep token values out of Git, workflow output and build artifacts. Account and zone identifiers are not secrets. HTTPS keys are managed by Cloudflare.

## Verification

CD runs rule boundary tests and real WebSocket matching/reconnection checks before export. After deployment it checks `/health` and compares the publicly served, decompressed WebAssembly with the built file. `/health` reports Worker availability; two-client matching separately verifies the container backend.

Infrastructure references: [Cloudflare Containers](https://developers.cloudflare.com/containers/get-started/), [WebSocket forwarding](https://developers.cloudflare.com/containers/examples/websocket/), [static asset limits](https://developers.cloudflare.com/workers/platform/limits/).
