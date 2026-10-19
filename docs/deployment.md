# Deployment

Production: https://robocon2027.kotek7.com. Private repository:
`kotek-7/robocon-2027-game`. Push `main` or dispatch `.github/workflows/deploy.yml`.

## Architecture

Browser → Worker `/ws` → named Cloudflare Tunnel → OCI Osaka A1 Flex → Python
HTTP/WebSocket gateway → Godot 4.7.2 authoritative server.
Workers Static Assets still serves the browser game. CPU/free play is local.

The `doshisharobot` tenancy has a dedicated game VM: 1 OCPU, 4 GB RAM, 50 GB boot.
All automatic queues and private rooms use one process (128 peers / 32 rooms).
The simulation runs at 60 Hz and sends snapshots at 20 Hz. The game Docker
container has a 3 GB memory limit; unused scene/UI processing is disabled headlessly.

`robocon2027-origin.kotek7.com` routes through tunnel `robocon-2027-game` to
VM loopback port 8080. No public game port or public SSH tunnel is configured.
The Worker injects `X-Arena-Key` from its `GAME_ORIGIN_KEY` secret; the gateway
requires the same lowercase hex secret from `/etc/robocon/game.env`. Requests
without that key fail with 403. Never put it in browser exports or source control.
Worker Origin/method/pool validation remains in front of the server. Native clients
can omit Origin; this check is not user authentication.

`/health` checks the actual OCI process through the authenticated tunnel, with a
5-second timeout, no caching, and 503 on failure. `/index.wasm` preserves the gzip
representation and conditional requests, but strips Range requests. All other
assets are served directly. Keep the gzip Wasm below the 25 MiB static asset limit.

The old Cloudflare Container application was deleted after cutover; CLI readback
returned `No containers found`. There is no ARENA binding or container start path.
An inert `ArenaServer` export remains for the existing declarative DO namespace:
Cloudflare rejected removing the class and rejected reverting it to legacy
migrations. It returns 410 and clears any old alarm, and production does not route
to it. Match data never lived in that namespace; it is not a running game server.

## Release

1. GitHub-hosted Ubuntu validates Worker/gateway behavior, Godot rules and scenes,
   matchmaking/reconnects, the Docker image, Web export and Worker types/dry-run.
2. Web artifacts are retained for one day. The private repository's dedicated
   `robocon-oci` ARM64 runner checks out the same commit after validation succeeds.
   Only the trusted main branch has a deployment job; do not run pull-request or
   untrusted workflows on this runner. It has Docker access on the game VM.
3. `infra/oci/deploy.sh` builds native ARM64 with 768 MB / half-core build limits.
   It starts a candidate on loopback 18080, checks readiness, then replaces the
   process on 8080. On failed readiness it restores the previous container.
4. A GitHub-hosted publish job deploys the Worker/assets with repository secret
   `CLOUDFLARE_API_TOKEN`, compares public decompressed Wasm with the build, and
   checks the public WSS protocol without occupying a matchmaking seat.

The runner uses outbound GitHub connections; no CI SSH keys or OCI API credentials
are stored in GitHub. Runner auto-updates are enabled. Service:
`actions.runner.kotek-7-robocon-2027-game.robocon-oci.service`.

Replacement **resets in-memory matches and reconnect tokens**. Candidate readiness
and rollback do not make active matches persistent, and frontend/backend releases
are not atomic. Keep adjacent protocol versions compatible when changing them.
Perform disruptive deployments when players can tolerate a reconnect/new match.

## Operations and rollback

See [OCI setup](../infra/oci/README.md) for resource provisioning and SSH access.
The gateway and tunnel use Docker `unless-stopped` restart policies and bounded
logs. An unexpected Godot exit terminates the supervisor so Docker can restart it.

Check `docker ps`, `docker stats --no-stream`, disk space and the public `/health`.
Run manual releases as `arena-runner` too (not root), so the deployment lock is
shared with CI and retains the same owner. Previous image/container state is
retained by the deployment script. To restore
it, stop/remove the current game container, rename `robocon-2027-game-previous`
to `robocon-2027-game`, then start it; verify public health and WSS. Restore a
compatible Web release through CD if its protocol changed. Do not recreate the
old Cloudflare Container as an automatic fallback.

Periodically remove obsolete **game** image tags/build cache after checking the
current and previous image IDs. Do not delete the current or rollback image.
Credentials remain outside the repository. Reprovision the named tunnel and runner
if restoring a lost VM; the provisioner creates compute/networking only.

## Cutover verification — 2026-10-19

Chrome also loaded the production Web export, created a private room and started
a match on the OCI backend without console errors. Public WSS private-room checks passed for 1v1 (2 humans) and 2v2 (4 humans), with
movement, game snapshots and token-based reconnect. Thirty application-level
rejection responses measured median **16.65 ms**, p95 **17.83 ms**, maximum
**17.83 ms** from the operator's connection. Median snapshot intervals were
49.96 / 49.88 ms. This is a small live sample, not a capacity or geographic SLA.
The earlier Cloudflare public sample had median 314 ms; it was collected at a
different time, not as a controlled simultaneous benchmark. WebSocket ping alone
measures the edge, so it is not the latency metric used here.

Reproduce safely without entering public queues:

```sh
python3 tests/deployment_smoke.py wss://robocon2027.kotek7.com/ws
python3 tests/production_rooms.py wss://robocon2027.kotek7.com/ws
```

The complete [CI run 39266482274](https://github.com/kotek-7/robocon-2027-game/actions/runs/39266482274)
passed validation, native OCI deployment and public asset/protocol verification.
The running image revision was read back as `ef26246865aa1deb112d9defff9c3e778db10088`,
with zero restarts and no OOM. Its first deployment attempt exposed a root-owned
lock from manual validation; ownership was corrected to `arena-runner`, then the
failed deployment/publish jobs were successfully retried using the validated build.

## Cost

New VM plus existing Outline allocation: 2 OCPUs / 10 GB RAM / 100 GB boot storage.
For 31 days: 1,488 OCPU-hours and 7,440 GB-hours. This fits even the smaller
published 1,500 / 9,000 A1 monthly allowance, assuming no other current-month usage.
Boot/block volumes share a 200 GB home-region allowance. No extra data disk,
load balancer, paid tunnel plan or VM was added for deployment.

OCI's covered compute/storage is therefore expected to be $0 incremental within
those allowances. Billing has not been audited: previous resources, backups,
network usage and taxes can change the bill. Existing Workers Paid base charges
and any other Cloudflare usage remain; deleting the Container does not cancel the
account-wide Workers plan. Always Free idle reclaim/capacity constraints remain.

References: [OCI Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm),
[OCI pricing](https://www.oracle.com/cloud/price-list/),
[boot volume minimum](https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/bootvolumes.htm),
[Cloudflare Tunnel](https://developers.cloudflare.com/tunnel/get-started/).
