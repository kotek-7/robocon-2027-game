# Audio and player identity

Music and sound effects: **Koichi Morita / MaouDamashii (魔王魂)**, https://maou.audio/ . Used under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); source terms: https://maou.audio/rule/ . The BGM is [Neorock 44](https://maou.audio/bgm_neorock44/), using the official game-loop MP3. Original files remain unchanged; playback applies gain, pitch and looping. `assets/audio/sources.json` records every URL and SHA-256.

| Source cue | Uses |
| --- | --- |
| System 08 | Menu focus, camera gesture onset, final countdown |
| System 49 | Confirm, reconnect |
| System 18 | Back, pause, unavailable action, disconnect, buzzer |
| System 03 | Start, retry |
| System 17 | Robot switch, resume, overview |
| System 10 | Cargo selection, score, fullscreen |
| Sound 23 (roller) | Per-robot movement loop |
| Sound 05 (winding) | Stair operation start |
| Sound 19/20 (metal open/close) | Manipulator start, pickup, placement, landing, brake, contact |
| Onepoint 15/14 | Win/lose, match found, Mustika |
| Onepoint 20 | Tower flip, Mustika eligibility |
| Onepoint 24 | Handover, time warning, draw |

UI inputs trigger UI cues. Competitive cues follow monotonic event IDs in authoritative snapshots; the last 64 events are retained. Audio consumes each event once, primes its cursor on reconnect, and discards events while the gameplay presentation is paused. Music and SFX have separate saved levels; zero mutes that bus. Four movement voices and twelve one-shot voices bound resource use. Repeated cues have short cooldowns, remote events are quieter, and continuous movement stops on pause, focus loss and match end. Missing or locked audio never delays a game command. Browser playback starts after a user gesture. Human listening and subjective mix balance remain separate from automated signal checks.

Names are generated on first visit and saved on the device. The profile editor is available from the title's name button. Names allow letters, numbers, spaces, dot, underscore and hyphen, up to 16 characters. Empty/reserved CPU names become Pilot; controls and bidi overrides are excluded. Japanese text uses M PLUS 1p, distributed under OFL from https://github.com/google/fonts/tree/main/ofl/mplus1p . Names are presentation text, not account identities.

The server normalizes names on enqueue and freezes them for the assigned match. Seat tokens preserve names and ownership through reconnect and rematch. In 1v1 each player's name covers both robots. In 2v2 each seat labels its own robot. In VS CPU, the human-selected robot shows the local name; all AI-driven robots show CPU. Nameplates show only the nickname or CPU, with a team-color marker; the controlled robot uses gold lettering.
