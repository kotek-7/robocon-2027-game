# Competition model

Source: local ABU Robocon 2027 v1.1 file, SHA-256 `f30391eac735191fabd7939a1f61b60a525ed84a89be1df17d4e21d8aa8bede2`. CAD SHA-256 `a8889d34d2074c85455599bd6f0aa0143d9ae6ab6474f6af266852f60fa5fd41`. The Japanese reference translation and block appendix accompany these files. The English rulebook controls discrepancies.

Terminology follows `gakusei-robocon/web/src/editors/common/labels.ts`: TR, BR, アースブロック, スカイブロック, ムスティカ, 受け渡しエリア, 建設スポット. Visible gameplay mostly uses shapes and numerals.

## Decisions

- 180 seconds, with no early finish for Mustika. Objects still held at the buzzer do not score tower or mission points. Already-earned transfer points remain.
- TR holds three blocks, BR two. Both teams use 1.7 m/s maximum driving speed and the same fixed acceleration. Picking and delivery take 0.65 seconds; placement and flipping take 1.1 seconds. These timings are game tuning, not measured robot performance.
- Transfer: 5 per Earth/Sky block, once per block per team. Direct handover and floor delivery are supported. Floor inventory is represented by eight slots within the area; this buffer limit is a game simplification.
- L1: first Earth 10, second Earth 20, Sky 40. L2 doubles these values. Earth ownership remains with its placing team; Sky follows its upper color.
- Mustika: 250 when placed on the central pillar. Eligibility requires two simultaneously owned completed towers, at least one shared; eligibility then remains unlocked. This follows the neighboring project's default simultaneous interpretation and rule 3.6.2's retained eligibility.
- Sky flipping is supported. Sky relocation and removal of an enshrined Mustika are disabled, matching the conservative neighboring defaults.
- Retry returns held objects to their initial positions, following 5.1.1. This intentionally differs from the neighboring exploration default `retry_payload=retain`; that project exposes the ambiguity with 5.3.2 as a hypothesis. Transfer history is retained.
- BR uses an explicit stair action: GND→L1 takes 3 seconds; L1↔L2 takes 2 seconds. These are game timings, not official durations. Movement cannot enter the stair footprint. Steering is locked during a climb; robot switching lets it finish, and retry cancels it. An occupied landing prevents entry. BR cannot descend the GND stairs. TR can also use the GND↔Transfer stairs. Both robots can use the ramp; TR remains excluded from the rest of L1 and all of L2. Ramp access by BR is an explicit game interpretation; rule 4.3.2 specifically mentions ground contact during retries and approach to the L1 stairs.
- Ties use score, Mustika, Sky count, L2 blocks, L1 blocks; remaining ties are draws in this game.

## Physical model

The supplied CAD drives rendering and sampled surface heights. The collision model uses a 0.2 m floor grid and a robot footprint with a 0.21 m clearance probe. This approximates ramp motion; stairs use fixed CAD entry and landing points. It is not a machinery feasibility simulation. Both teams share the same collision model. Role and territory restrictions prevent illegal entry.

BR is manually controlled in the game. Pickup and placement use proximity assistance, carried blocks attach to the robot, and placed blocks snap to the designated spot. Manipulator trajectories, gripping force, accidental dropping and referee judgment of intent are not simulated. There is no pushing or combat mechanic. Illegal actions are unavailable rather than narrated as penalties.

Human and AI use the same command/context validation. In VS CPU, the non-selected friendly robot is AI-controlled; both opposing robots have separate AI drivers. Switching immediately transfers driving authority, while an already-started job completes normally. In online 1v1, each player switches between TR and BR and the inactive robot waits. In online 2v2, each player has one fixed robot; the server ignores switch requests and client-supplied robot identifiers. The authoritative room server runs at 60 Hz and publishes state at 20 Hz. Reconnection requires a random session token and must occur within 30 seconds; the clock continues.

## Initial block layout

Earth stock uses ten columns per team, each two blocks high, inside the CAD storage bounds: |X| 3.5–5.45 m, Z −5.45 to −4.5 m. Rule 4.1.3 permits a team-selected layout within that area, with at most two blocks per column. This game fixes a 5 × 2 column layout. Sky stock follows Figure 4 (rulebook page 15): even checkerboard cells of the 5 × 5 grid, center empty, with each two-color cube initially lying sideways. Its red half points N/S/E/W according to the diagram; a tower placement turns the scoring color upward.

## BR return and cargo rotation

A full BR can use the normal action at its own Transfer Area to return its selected carried object to the floor (0.65 seconds, the same as a normal delivery). The next action retrieves another reachable buffer object; returned objects go to the back of the retrieval order, enabling round-robin cargo exchange. The buffer's eight-slot limit still applies. BR return grants no transfer points and does not erase already-earned TR delivery points. CPU drivers do not automatically undo their pickups with this operation.

This is an interpretation of v1.1 sections 4.3.2 and 4.4.1–4.4.3: BR can operate in the Transfer Area, objects must be lifted and carried, and release outside the area is a violation. The text does not explicitly describe a BR return operation. Transfer scoring remains restricted to TR under 8.1. An intentional placement inside the area is modeled separately from an accidental drop.
