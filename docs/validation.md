# Validation

Run date: 2026-10-15. Godot 4.7.2 Compatibility Web export, single-threaded. Linux desktop with Intel Arc MTL graphics, Mesa 25.2.8. Chrome for Testing 153.0.8010.12 (Playwright Chromium build 1243) and Firefox 157.0. Browser viewport: 1280 × 720.

## Competition logic

`tests/run.gd`: 31 assertions passed. Checks cover CAD levels, territory and step boundaries, interaction reach, carrying limits, delivery accounting, tower scores and ownership, retained Mustika eligibility, action completion at the buzzer, simultaneous object/tower reservations, retry, robot switching, snapshot serialization and a full CPU match. The CPU reached Mustika and scored 905 against an idle opponent. This is a functional run, not an AI strength benchmark.

## Online

`tests/network.py` passed against the native Godot WebSocket server: create/join/ready, authoritative movement, shared state, stale-input stopping, token reconnection and a 30-second disconnection forfeit while the match clock continued.

`tests/network_browser.py` passed with two Chromium clients using the visible menus: room creation, code entry, readiness, movement and synchronized positions/scores. Browser error list was empty. An online start opens the menu until the player clicks RESUME, allowing the browser to capture the mouse from a user gesture.

`tests/network_rematch.py` completed a natural 180-second server match and verified that both players requesting AGAIN resets the match and score. Tests used localhost; Internet latency, TLS deployment and remote-device reconnect behavior have not been validated.

## Presentation and scope

`tests/browser.py` passed in headed Chromium (Playwright build 1243), using ANGLE on Mesa Intel Arc MTL. It drove and picked up stock, switched robots, opened overview, verified focus-loss pause, returned held cargo with retry, reset FREE, ran a complete 180 seconds of gameplay, reached the result and restarted. The final CPU score was 905. The 47 five-second engine-FPS samples were all 60; samples include a foreground-loss pause near the end, which was resumed through the menu. No browser errors were recorded. The title was also captured at 960 × 600. This verifies one local GPU/environment, not a universal performance guarantee.

`tests/firefox_browser.py` passed on Firefox 157.0 on the desktop display: movement and TR/BR switching, 60fps at the sampled point, no JavaScript errors. This was a smoke check, not a full Firefox match or sustained performance test.

`tests/gamepad_browser.py` passed with a virtual standard Gamepad API device: stick movement and face-button robot switching. The Web Audio context was running after the initial click. Physical controller compatibility and audible output were not assessed by these checks.

Screenshots under `build/qa` record the title, driving view, overview, results, online menu and narrow desktop layout. A separate visual review accepted the revised exposure, font weight, pictorial controls and compact information button.

Performance results are sampled engine FPS, not frame-time percentiles. Software-rendered Chromium and Firefox runs were much slower and do not establish the 60fps target. Human playtesting for enjoyment, physical gamepad hardware and subjective sound balance remain untested. CAD collision sampling and robot operation are simplified as described in `rules.md`.

Raw reports and captures are generated locally under `build/qa`; they are excluded from the Web export.
