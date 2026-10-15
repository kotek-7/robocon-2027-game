# Validation

Run date: 2026-10-15. Godot 4.7.2 Compatibility Web export, single-threaded. Linux desktop with Intel Arc MTL graphics, Mesa 25.2.8. Chrome for Testing 153.0.8010.12 (Playwright Chromium build 1243) and Firefox 157.0. Browser viewport: 1280 × 720.

## Competition logic

`tests/run.gd`: 31 assertions passed. Checks cover CAD levels, territory and step boundaries, interaction reach, carrying limits, delivery accounting, tower scores and ownership, retained Mustika eligibility, action completion at the buzzer, simultaneous object/tower reservations, retry, robot switching, snapshot serialization and a full CPU match. The CPU reached Mustika and scored 905 against an idle opponent. This is a functional run, not an AI strength benchmark.

## Initial online baseline

`tests/network.py` passed against the native Godot WebSocket server: create/join/ready, authoritative movement, shared state, stale-input stopping, token reconnection and a 30-second disconnection forfeit while the match clock continued.

`tests/network_browser.py` passed with two Chromium clients using the visible menus: room creation, code entry, readiness, movement and synchronized positions/scores. Browser error list was empty. An online start opens the menu until the player clicks RESUME, allowing the browser to capture the mouse from a user gesture.

`tests/network_rematch.py` completed a natural 180-second server match and verified that both players requesting AGAIN resets the match and score. These baseline tests used localhost. Public deployment checks are recorded below; remote-device reconnect behavior remains untested.

## Presentation and scope

`tests/browser.py` passed in headed Chromium (Playwright build 1243), using ANGLE on Mesa Intel Arc MTL. It drove and picked up stock, switched robots, opened overview, verified focus-loss pause, returned held cargo with retry, reset FREE, ran a complete 180 seconds of gameplay, reached the result and restarted. The final CPU score was 905. The 47 five-second engine-FPS samples were all 60; samples include a foreground-loss pause near the end, which was resumed through the menu. No browser errors were recorded. The title was also captured at 960 × 600. This verifies one local GPU/environment, not a universal performance guarantee.

`tests/firefox_browser.py` passed on Firefox 157.0 on the desktop display: movement and TR/BR switching, 60fps at the sampled point, no JavaScript errors. This was a smoke check, not a full Firefox match or sustained performance test.

`tests/gamepad_browser.py` passed with a virtual standard Gamepad API device: stick movement and face-button robot switching. The Web Audio context was running after the initial click. Physical controller compatibility and audible output were not assessed by these checks.

Screenshots under `build/qa` record the title, driving view, overview, results, online menu and narrow desktop layout. A separate visual review accepted the revised exposure, font weight, pictorial controls and compact information button.

Performance results are sampled engine FPS, not frame-time percentiles. Software-rendered Chromium and Firefox runs were much slower and do not establish the 60fps target. Human playtesting for enjoyment, physical gamepad hardware and subjective sound balance remain untested. CAD collision sampling and robot operation are simplified as described in `rules.md`.

Raw reports and captures are generated locally under `build/qa`; they are excluded from the Web export.

## Automatic matchmaking and vivid palette update

The room-code UI was replaced with a compatible FIFO queue. The protocol rejects obsolete clients and preserves cancellation revisions. Local protocol checks passed for cancellation, duplicate enqueue, assignment, movement, stale-input stopping, reconnect and forfeit. Two Chromium clients matched through ONLINE and shared authoritative state without browser errors.

The new palette was inspected at 1280 × 720 and 960 × 600, with title, driving and overview captures in `build/qa/vivid-*.png`. Yellow platforms, cyan surroundings and saturated team colors replace the pastel palette; actionable targets use a white ring with a dark edge.

GitHub Actions run [38678208335](https://github.com/kotek-7/robocon-2027-game/actions/runs/38678208335) passed the rule suite, matchmaking suite, Web export, Docker server check, Cloudflare deployment and public asset verification. The live endpoint is https://robocon2027.kotek7.com. Two public WSS clients matched successfully. The public, decompressed WebAssembly matched the build byte for byte.

A fresh Chromium client reached the title without JavaScript or Godot errors. Its first WebAssembly download transferred 10,055,058 bytes including response overhead in 133.6 seconds on this desktop connection. The initial 60-second test timeout was too short. This is a cold-load measurement, separate from gameplay FPS.

Two fresh Chromium clients then passed the full ONLINE UI check against the public URL: automatic pairing, direct robot movement, synchronized positions and scores, and zero browser errors. Captures and the report are `build/qa/online-production.png` and `build/qa/network-browser-production.json`. Public cold-load waits were extended to 240 seconds for this check.

## Stair actions and stadium presentation

The CAD mesh now uses flat face normals with darker risers, white tread nosings and a stronger directional shadow. Its height coordinates and competitive footprint are unchanged. Spectator seating, 160 animated crowd figures, balloons and two inflatable arches sit outside the field. Placement and landing emit a bounded pool of at most 80 confetti pieces; decorative meshes have no collision.

`tests/run.gd`: 45/45 passed, including timed ascent/descent, blocked landings, forbidden TR stair use, movement lock, inactive robot completion, carrying, retry, snapshot roundtrip and buzzer ordering. The CPU still completed the 180-second simulation with Mustika and 905 points.

`tests/stairs_browser.py` drove a BR from its start through both stair entries with keyboard input, switched robots during the first ascent, and confirmed both landings. Chromium recorded no browser errors and six 60fps samples at 1280 × 720 with the new scenery. These samples are not a sustained frame-time benchmark or a human enjoyment evaluation. Captures: `build/qa/stadium-title.png`, `stairs-entry.png`, `stairs-climbing.png`, `stadium-overview.png`, `stadium-play.png`.

Firefox 157 smoke checks passed with the new scenery: movement, robot switching, a 60fps sample and zero browser errors. CD run [38680079186](https://github.com/kotek-7/robocon-2027-game/actions/runs/38680079186) deployed commit `974e458` and passed public asset verification. After the container rollout, public WSS clients matched with ruleset r2 and completed authoritative three-second GND→L1 and two-second L1→L2 operations, including switching away during ascent and receiving the completed landing through snapshots.

## Touch controls, landscape gate and fullscreen

`tests/touch_browser.py` passed in Chromium mobile emulation at 844 × 390 and 390 × 844. It sends real browser touch events through CDP: simultaneous movement/look, releasing one finger while the other continues, cancellation stopping locomotion, ACT pickup, robot switching, overview toggle, portrait input/time blocking in FREE, rotation back to landscape, and fullscreen enter/exit. No pointer lock was requested and the browser error list was empty. The portrait gate leaves online match clocks running and sends neutral input. Touch state resets on menus, focus loss and viewport changes.

The full 45 competition checks passed unchanged. Android hardware, iPhone/Safari hardware, device-specific orientation-lock behavior and mobile GPU performance have not been tested. Fullscreen availability is detected at runtime; orientation lock is requested after fullscreen succeeds. Browsers that reject orientation lock still require landscape through the portrait gate. Captures and touch report are under `build/qa/touch-*`.

The same touch sequence passed at device pixel ratio 2, including fullscreen toggling, with zero browser errors. CD run [38681305651](https://github.com/kotek-7/robocon-2027-game/actions/runs/38681305651) deployed commit `e6e5b6f` successfully. The public PCK was read back and contains the touch controller and fullscreen asset. Desktop two-browser matchmaking and movement/state synchronization also passed without browser errors.

## Stock layout, traversal and browser controls

The competition suite passes 53/53 checks with ruleset r3. Added cases cover Earth storage bounds and two-block stacks, the twelve sideways Sky cubes from Figure 4, TR stair ascent/descent and L2 exclusion, BR ramp access, and Sky orientation after retry. The standard CPU completes the 180-second simulation, enshrines Mustika and scores 665 with this layout. Earlier scores above describe earlier layouts.

The title uses outlined Fredoka lettering, a gold Mustika and cyan/gold subtitle lines. Fullscreen controls have a fixed 44-pixel target, consistent hover/focus styles and input priority over the menu overlay. Pointer-lock rejection no longer triggers a second pause after retry; losing an established lock still pauses. Local matchmaking and network checks passed, including token reconnect and the 30-second disconnect grace period.

`tests/fixes_browser.py` passed in headed Chromium at 1280 × 720 with zero browser errors. It clicks the actual fullscreen button twice, checks the complete page title, simulates browser pointer-lock rejection during retry and then drives the robot, drives TR to its GND stair entry and completes the timed ascent, and drives BR up the ramp. Captures: `mustika-title.png`, `fullscreen-focus.png`, `tr-stair-transfer.png`, `br-ramp.png` under `build/qa`.

The touch regression passed again at 844 × 390 and 390 × 844, including simultaneous move/look, pickup, switching, portrait blocking and fullscreen, with zero browser errors. The compact title and menu fit the landscape viewport. Mobile checks use Chromium emulation; physical phones remain untested.

Firefox 157 smoke checks passed for movement and robot switching, with a 60fps sample and zero browser errors. CD run [38703601485](https://github.com/kotek-7/robocon-2027-game/actions/runs/38703601485) deployed commit `9c6ad6b` and passed public asset verification. The public HTML serves the full title, and two public WSS clients matched with ruleset r3. The first connection attempt timed out during container startup; a subsequent attempt with a 40-second opening timeout succeeded.

## CPU partner and online team formats

The rule suite passes 57/57 checks. Fixed robot commands share the existing movement and action validation. Added checks verify that a CPU partner leaves the human-controlled robot alone, approaches the transfer area as BR, takes over TR after switching, and completes a 180-second match with two simultaneous opposing pilots (605 points).

`tests/modes_browser.py` passed with four headed Chromium clients and zero browser errors: CPU partner movement, Q handoff, selection of the 2v2 queue, four unique robot assignments, BR movement on both teams, ignored switch requests in 2v2, and synchronized positions. The title is captured at 1280 × 720 with 80px primary lettering and a 540px menu width. The mobile title uses 42px lettering and a 370px menu width.

`tests/teams_network.py` passed against the headless server: separate 1v1/2v2 queues, all four ready acknowledgements, fixed seat authority despite a forged robot ID, reconnect to the same BR, and team forfeit after a disconnected seat's grace expires. This test also runs in CD. Queued and assigned sessions continue to use the existing cancellation revisions and reconnect tokens.

The existing 1v1 protocol and two-browser movement/synchronization checks also passed through the new format picker. Chromium mobile emulation at 844 × 390 and 390 × 844 passed the touch suite with the enlarged title, including simultaneous input, pickup, portrait gating and fullscreen. These checks do not cover physical phone performance.

`tests/network_rematch.py --2v2` completed a natural 180-second four-player match, verified that three votes do not reset it, and confirmed a fresh match with zero scores after the fourth vote.
