# OCI game server

The game has a separate `VM.Standard.A1.Flex` VM in the `doshisharobot` tenancy's
home region (`ap-osaka-1`). It does not share the Outline VM or its VCN.

- 1 OCPU, 4 GB RAM, 50 GB boot volume, Ubuntu 24.04 ARM64.
- One Godot process, with automatic 1v1/2v2 queues and private rooms.
- Dedicated VCN `10.43.0.0/16`, subnet `10.43.1.0/24`.
- SSH is allowed only from the administration address supplied at provisioning.
- The game gateway binds to VM loopback; no public game port is opened yet.
- Cloudflare remains the production backend until a separately verified cutover.

## Provision

Configure OCI API authentication in `~/.oci/config` for `doshisharobot`.
Use a dedicated SSH key outside the repository:

```sh
ssh-keygen -t ed25519 -f ~/.ssh/robocon_2027_oci
uv run --with oci==2.187.2 python infra/oci/provision.py --ssh-cidr YOUR_PUBLIC_IP/32
```

The script checks the tenancy name, reuses uniquely named resources, and records
resource identifiers in ignored `build/oci/resources.json`. It does not change an
existing application's resources. On a failed launch, inspect that file and the
OCI resource states before rerunning or cleaning up. Never delete resources by
compartment alone. Re-running does not update an existing security list/VM; review
its actual configuration if the admin IP or requested settings change.

Wait for the VM to reach RUNNING, obtain its VNIC public IP, then connect as
`ubuntu` using the dedicated key. `sudo cloud-init status --wait` installs Docker;
`/var/lib/robocon-bootstrap-complete` marks completion.

## Install and validate

Copy only Dockerfile, .dockerignore, project.godot, main.tscn, icon.svg,
default_bus_layout.tres, scripts/, assets/, scenes/, resources/, and
cloudflare/server.py into `/opt/robocon-2027-game`. No API keys, repository tokens
or local environment files belong on the VM.

Build on the ARM64 VM:

```sh
cd /opt/robocon-2027-game
sudo docker build --build-arg TARGETARCH=arm64 -t robocon-2027-game:oci .
sudo docker run -d --name robocon-2027-game --restart unless-stopped \
  --memory 3g --pids-limit 256 --cap-drop ALL --security-opt no-new-privileges \
  --log-driver json-file --log-opt max-size=10m --log-opt max-file=3 \
  -p 127.0.0.1:8080:8080 robocon-2027-game:oci
curl --fail http://127.0.0.1:8080/health
```

The image verifies architecture-specific Godot SHA-256 checksums. CPU is available
to the single server; the memory cap leaves approximately 1 GB for Ubuntu/Docker.
The restart policy handles reboot/process failures. It does not preserve matches.

For the existing local network tests, forward a free local port:

```sh
ssh -N -L 127.0.0.1:9080:127.0.0.1:8080 -i ~/.ssh/robocon_2027_oci ubuntu@VM_IP
python3 tests/matchmaking.py
python3 tests/private_rooms.py
python3 tests/network.py
python3 tests/teams_network.py
python3 tests/partners_network.py
```

These tests use the real ARM64 game server via SSH, not a production WSS route.
Check CPU, memory, restart count and game latency before publishing a TLS endpoint.
Cloudflare's public routing and GitHub CD still target Cloudflare Containers.

## Cost and lifecycle

The existing Outline VM was read back as 1 OCPU / 6 GB / 50 GB before creation.
The combined intended running capacity is 2 OCPUs / 10 GB / 100 GB boot storage.
For a 31-day month this is 1,488 OCPU-hours and 7,440 GB-hours, within even the
smaller documented 1,500 / 9,000 monthly A1 allowance if no other usage consumes it.
Current-month terminated/replaced resources, backups, networking and taxes must
be considered separately; this is not a billing guarantee.

The 50 GB disk is a standard OS boot-volume allocation, not a game-data estimate.
OCI custom boot sizes must meet the platform image / 50 GB minimum; no additional
data disk is created. Home-region boot and block storage share the 200 GB allowance.

Always Free idle reclaim and regional capacity availability remain operational
constraints. OS/Docker updates and recovery are the operator's responsibility.
Keep the image, source revision and provisioning instructions reproducible.

## Provisioned validation (2026-10-19)

The VM was read back as RUNNING with the requested A1 shape, 1 OCPU and 4 GB.
Both Outline and the game were RUNNING; their boot volumes were 50 GB each.
A second provisioner run reused all six recorded resources without creating duplicates.
Cloud-init completed, Docker 29.1.3 started, and the native ARM64 image built
successfully with Godot 4.7.2. The transferred source archive matched its local SHA-256.
The game container initially reported running, zero restarts and no OOM.

Disk use after building was about 3.3 GB (48 GiB filesystem, 45 GiB free).
One sample during network tests reported 9.15% CPU and 64.66 MiB container memory;
this is not a peak-load capacity guarantee. An application-level rejection probe
(no public queue seat allocated) over SSH measured 30 samples: median 16.77 ms,
p95 35.14 ms, maximum 62.54 ms while regression tests ran. This is a direct SSH
path to Osaka, not the future public WSS path, so the previous Cloudflare public
median of 314 ms is not an apples-to-apples deployment benchmark.

All five existing network suites passed against the ARM64 VM through the tunnel:
automatic matchmaking, private rooms (1–4 humans), authoritative 1v1, fixed-seat
2v2, and CPU partners. These include cancellation, robot switching, reconnects
and the 30-second disconnect forfeit.

Public TLS routing, browser play through that routing, and CI deployment to OCI
remain separate cutover work. The SSH tunnel used for validation is temporary.
