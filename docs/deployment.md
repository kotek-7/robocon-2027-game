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
| Three named DOs, `max_instances: 3` | `auto-1v1`, `auto-2v2`, `casual-v2` (private/legacy) keep opponents and reconnects together |
| Custom 1 vCPU / 3072 MiB / 4000 MB | Four times the former basic CPU ceiling, with less provisioned memory/disk than standard-2 |
| APAC placement | Bounds placement to Asia Pacific; not a guarantee of a specific city or RTT |
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
- `setInactivityTimeout(60000)` is set during startup and restored in the constructor
  if a Container survives DO reconstruction. The timer applies after the DO becomes
  inactive; an open WebSocket can keep it active. It is not a one-minute match limit.
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
This is bounded cleanup, **not match draining**. Each container has at most 128 peers and
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


## Three-pool routing and cost envelope

The client chooses `/ws?pool=1v1`, `2v2`, or `room` before opening the socket.
The Worker accepts only these three values, maps them to fixed DO names and uses
an APAC DO location hint. Hints apply on initial DO creation; they do not relocate
the existing `casual-v2` DO. Container placement constraints apply independently.
The client retains the exact URL during reconnection.
Private hosts and guests share `casual-v2`, preserving six-character room codes.
The query-less legacy endpoint also goes there. Already-open old clients must
reload to participate in the new automatic pools; legacy automatic clients only
see each other. There is no random per-socket routing, queue fragmentation within
a current-client format, additional coordinator DO, or periodic warm-up.

This is **mode partitioning**, not even distribution or load-based autoscaling.
A surge of only 1v1 players still uses one container. Moving individual matches
across three servers would require a shared matchmaker and explicit handoff; simply
using `getRandom` would strand players and break reconnections. See the official
[scaling guide](https://developers.cloudflare.com/containers/configuration/scaling-and-routing/).

The server caps idle processing at 60 FPS and disables presentation children
(stadium animation, UI and effects); authoritative physics remains 60 Hz and
snapshots remain 20 Hz. `--headless` alone did not disable those scripts.

Using the [2026-10-19 published rates](https://developers.cloudflare.com/containers/platform/pricing/),
per running container-hour: memory $0.027 + disk $0.001008 + CPU $0–$0.072
(actual CPU consumption). At 10% CPU this is $0.035208/h; at 100% $0.100008/h.
Three containers each running two hours daily for 30 days are about **$6.34–$18.00**
at those utilization levels. Three running continuously for 30 days are about
**$76.05–$216.02**. These are Container compute estimates before included usage,
not total bills: add the Workers plan ($5/month), applicable Worker/DO/logs/network
charges and taxes. Idle timeout/startup time counts as running time. Open sockets
can keep a container alive; the instance count is a concurrency cap, not a spending
cap. A larger standard-2 would double provisioned memory to 6 GiB without adding CPU.

Before this change, a short production private match with two humans and two CPU
partners delivered 160 snapshots at median 48.85 ms, p95 57.04 ms, maximum 60.66 ms,
with simulated time/wall time 1.0001. This did not reproduce the reported lag and
does not prove CPU starvation or client rendering performance. Scaling therefore
adds headroom; it is not a verified cure for every source of perceived latency.

A separate 20-request application-level probe (invalid queue protocol, no queue
seat allocated) measured median 314.41 ms / maximum 633.83 ms round trip to Godot.
WebSocket control ping alone measured 5.53 ms median and does not measure the full
application path. This points to backend placement/routing as another candidate
cause; it is not proof that additional CPU alone fixes the reported experience.

Local validation of the three-pool change: 23 Worker/Container unit tests; strict
Worker types and Wrangler dry-run; 69 competition checks; scene mapping; actual
client upgrade request paths for all three pools; server-only processing; and real
Godot matchmaking, private rooms, 1v1, 2v2 and CPU-partner/reconnect/forfeit suites
passed. The scene suite still emits resource-leak warnings at shutdown. Docker
remains unavailable locally, so actual three-Container integration and post-release
latency comparison remain pending CI/deployment.
