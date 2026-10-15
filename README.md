# Robocon 2027 Game

A three-minute robot match for PC browsers. Drive TR and BR, carry blocks, build towers and contest Mustika.

## Run locally

Requires Godot 4.7.2, matching Web export templates and Python 3.

```sh
./tools/run_local.sh
```

Open http://localhost:8087. The script exports the game, serves the Web build and runs the room server on port 9080. Stop it with Ctrl+C.

Alternatively, open `project.godot` in Godot and run the main scene. Use `godot --headless --path . -- --server` for the room server.

## Controls

WASD moves relative to the camera. Mouse orbits. E interacts, Q switches robots, mouse wheel selects cargo, Tab shows the field, Esc opens the menu. Gamepad: left stick moves, right stick orbits, lower face button interacts, upper face button switches, bumpers select cargo, left trigger shows the field, Start opens the menu.

VS CPU uses the same fixed robot performance and one active driver per team. FREE has no opponent or time limit. ONLINE searches for another player automatically. Compatible clients are paired in arrival order; CANCEL leaves the queue. Search times out after two minutes. Both players can request a rematch after the result.

## Delivery

Production target: `https://robocon2027.kotek7.com`.

Push to `main` to run `.github/workflows/deploy.yml`: competition and matchmaking checks, pinned Godot Web export, asset packaging, Cloudflare deployment and public artifact verification. The repository secret `CLOUDFLARE_API_TOKEN` authenticates deployment. Application deployment is performed by CD.

Cloudflare Workers serves the game and forwards `/ws` to one Godot container. The same host supplies HTTPS and WSS; players do not enter an endpoint. The container has a bounded casual queue and 32 simultaneous matches. In-memory matches are lost when the server process is replaced. Browser WebAssembly is served with gzip encoding to stay below the individual static asset limit.

See [deployment configuration](docs/deployment.md) for infrastructure and credentials.

## Checks

```sh
godot --headless --path . --import
godot --headless --path . --script tests/run.gd
# With the room server running, in an environment containing websockets:
python tests/matchmaking.py
python tests/network.py
# With Playwright and the Web build served on 8087:
python tests/browser.py
python tests/network_browser.py
python tests/network_rematch.py
python tests/gamepad_browser.py
python tests/firefox_browser.py
```

The browser harness uses `?qa=1` for read-only state and UI bounds. It sends keyboard/mouse inputs; it cannot alter match state through that interface. Browser evidence is written under `build/qa`. Run browser checks sequentially because changing the foreground window pauses local play. The harness currently uses the local Playwright Chromium path; adjust it for another machine. The gamepad check injects Gamepad API inputs, not match state.

See [validation results](docs/validation.md) for tested environments and remaining checks.

## Sources

The original rulebook, Japanese reference translation, block appendix and STEP field are in `rulebook/`. `assets/field.json` is a tessellation of that exact STEP; `tools/prepare_field.py` verifies the SHA-256 before reusing the neighboring project's tessellation. Coordinates are metres, Y up. Source STEP X maps to X, Z minus 1 mm to Y, and negative Y to Z.

Rule decisions and simulation boundaries are recorded in `docs/rules.md`. Fredoka is distributed under the SIL Open Font License, included beside the font.
