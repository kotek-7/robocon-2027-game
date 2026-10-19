# Deployment

Host: `robocon2027.kotek7.com`. GitHub repository: `kotek-7/robocon-2027-game` (private).
Release through `.github/workflows/deploy.yml` on `main` or manual dispatch. Godot
and npm dependencies are pinned; Godot archives are SHA-256 verified. Local checks
and dry-runs do not deploy production.

## Architecture and API choice

Browser → Worker `/ws` → `ArenaServer` Durable Object → Container port 8080 →
Python gateway → authoritative Godot server. Static files use Workers Static Assets.
CPU/free play runs entirely in the browser.

`ArenaServer` extends `DurableObject` from `cloudflare:workers` and uses
`ctx.container` directly. There is no `@cloudflare/containers` dependency or custom
WebSocket message relay in the Worker. This follows the recommendation for new
applications in the [Durable Object Container API reference](https://developers.cloudflare.com/containers/api/durable-object-container/).

API and scheduling policy are separate choices. Evaluated as a new service:

| Choice | Reason |
| --- | --- |
| Direct Durable Object Container API | Explicit readiness and lifecycle using the platform API |
| `default` scheduling policy | All game servers use the same image and size; Cloudflare manages image rollouts |
| Single named DO (`casual-v2`), `max_instances: 1` | Public matchmaking and private rooms share one authoritative process |
| `basic` instance | Current configured capacity; load-tested sizing is still outstanding |
| SQLite class export | Supported DO namespace backend; not a persistence layer for Godot matches |

The official [policy selection guide](https://developers.cloudflare.com/containers/configuration/scheduling-policy/)
assigns `default` to same-image/same-size services. The beta `durable_object` policy
is for per-instance image/size selection, such as sandboxes. It removes managed
application rollouts and `max_instances`; this game does not need those per-instance
choices. `default` is selected for the workload, not to avoid migration.

## Startup, sockets and shutdown

- Concurrent requests share one startup/readiness promise. Allocation and HTTP
  readiness failures retry within a 30-second loop, with 1-second probe timeouts.
  The gateway must return a successful `/health` response; an open port alone is
  insufficient. Probe bodies are cancelled. A failed attempt releases the promise
  so a later request can recover.
- Requests are forwarded with an internal HTTP host and preserved path/query and
  Origin. The port's response is returned directly, retaining the WebSocket upgrade,
  following the [official forwarding example](https://developers.cloudflare.com/containers/examples/websocket/).
  Forwarding failures return non-cacheable 503 responses and are not automatically
  replayed. Startup is shared independently of one caller's cancellation.
- `start({ enableInternet: false })` uses the image/size in Wrangler. There is no
  outbound Internet requirement for the game server.
- `setInactivityTimeout(600000)` is set during startup and restored in the constructor
  if a Container survives DO reconstruction. The timer applies after the DO becomes
  inactive; an open WebSocket can keep it active. It is not a ten-minute match limit.
  No recurring polling alarm or lifetime `monitor()` promise is installed.
- The previous helper's persisted sleep alarm is deleted in the constructor. No
  application data is deleted. This implementation does not schedule DO alarms.
- The Python gateway listens only after Godot is accepting connections. It parses
  bounded HTTP headers, serves `/health`, accepts `/ws` (`/` for local test clients),
  and closes both relay directions when either side ends. It handles SIGTERM even
  during startup, reaps the child on failure, and kills it if termination exceeds
  five seconds. Unexpected child exit fails the supervisor.

The platform sends SIGTERM during shutdown/rollout; see
[Container lifecycle](https://developers.cloudflare.com/containers/concepts/architecture/).
This is bounded cleanup, **not match draining**. There are at most 128 peers and
32 rooms; matches, queues, room codes and reconnect tokens reside in Godot memory.
Container replacement loses them. No DO storage, filesystem snapshot or R2 write
currently persists them. Profile preferences remain local to the browser.

## Assets and HTTP boundaries

Only `/ws`, `/health` and `/index.wasm` run Worker code before asset lookup. The
packager clears its output and validates the 25 MiB individual asset limit.
Wasm is stored gzip-compressed; the Worker sets the representation headers and
`encodeBody: "manual"`. Conditional requests retain their status/ETag, while byte
ranges are removed so partial gzip files are never presented as complete Wasm.
Workers negotiates response encoding with the client.

Worker `/health` is non-cacheable liveness, not backend readiness. HEAD returns
no body. Unsupported methods are rejected before touching bindings. Browser
WebSocket requests with a foreign Origin are rejected. Origin checking does not
provide authentication; native clients can omit it. Static HTML/JS/PCK revalidate.

References: [asset routing](https://developers.cloudflare.com/workers/static-assets/routing/worker-script/),
[headers](https://developers.cloudflare.com/workers/static-assets/headers/),
[asset limits](https://developers.cloudflare.com/workers/static-assets/billing-and-limitations/),
[Response API](https://developers.cloudflare.com/workers/runtime-apis/response/).

## Configuration and release

`wrangler.jsonc` is the deployment source of truth. The compatibility date is
`2026-10-19`; source maps and observability are enabled. Only the custom domain is
published (`workers_dev` and `preview_urls` disabled). Generated runtime/binding
types are ignored and regenerated for strict JS typechecking. Secrets belong in
GitHub's `CLOUDFLARE_API_TOKEN` secret or ignored local `.dev.vars`, never source.
The deployment token needs account/container/Worker and custom-domain permissions.

The `ArenaServer` class, namespace and binding stay stable. Changing its base class
does not require a DO migration; see the [API replacement guide](https://developers.cloudflare.com/containers/guides/migrate-to-durable-object-container-api/).
SQLite is declared through `exports`; do not mix it with legacy `migrations`.
See [class exports](https://developers.cloudflare.com/durable-objects/reference/durable-objects-migrations/).

CI validates Worker and gateway behavior, game rules and networking, exports the
Web game, checks Worker types/bundling, builds/runs the Docker image, and runs
`wrangler dev` with `tests/container_runtime.py`. The latter exercises concurrent
cold upgrades and a private game through the actual Worker → DO → Container path.
Only then does CD deploy. Post-deploy checks compare decompressed public Wasm bytes
and exercise the Godot protocol over the public WebSocket without joining a queue.

[Deployment](https://developers.cloudflare.com/containers/guides/deploy/) activates
Worker code before processing the image and is not transactional. Successful deploy
means a rollout started, not that every instance replaced. The [rollout grace period](https://developers.cloudflare.com/containers/configuration/rollouts/)
is based on Container/DO connection age, not game age; it cannot guarantee ongoing
matches finish. The current smoke test proves backend reachability, not the image
revision. Keep Worker/container protocol changes compatible across that interval.

## Validation status — 2026-10-19

Passed locally: 19 Worker/direct-API tests using mocked platform bindings, generated
types and strict JS checking, and Wrangler dry-run (4.64 KiB Worker bundle).
The preceding gateway changes passed five real TCP/process tests and real Godot
matchmaking/private-room/reconnection/2v2/CPU-partner suites. Wasm gzip/identity,
HEAD, Range and conditional responses were checked with local workerd. The new
integration script also passed against the local Python gateway and real Godot;
that run validates the script/game interaction, not the direct API runtime.

The replacement direct API's actual Container integration and platform inactivity
behavior are **not yet verified**: Docker Desktop's socket is absent and the system
Docker socket is inaccessible to this user. The new Wrangler integration step is
configured in CI but has not been run here. No production deployment was performed.
