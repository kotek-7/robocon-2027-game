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
- BR uses the stairs rather than the TR ramp. After reaching L1 it cannot drive back down to the Ground Area except via retry.
- Ties use score, Mustika, Sky count, L2 blocks, L1 blocks; remaining ties are draws in this game.

## Physical model

The supplied CAD drives rendering and sampled surface heights. The collision model uses a 0.2 m floor grid and a robot footprint with a 0.21 m clearance probe. This approximates stair and ramp motion; it is not a machinery feasibility simulation. Both teams share the same collision model. Role and territory restrictions prevent illegal entry.

BR is manually controlled in the game. Pickup and placement use proximity assistance, carried blocks attach to the robot, and placed blocks snap to the designated spot. Manipulator trajectories, gripping force, accidental dropping and referee judgment of intent are not simulated. There is no pushing or combat mechanic. Illegal actions are unavailable rather than narrated as penalties.

Human and AI use the same command/context validation. AI may switch while a previously started action finishes, like a human. The authoritative room server runs at 60 Hz and publishes state at 20 Hz. Reconnection requires a random session token and must occur within 30 seconds; the clock continues.
