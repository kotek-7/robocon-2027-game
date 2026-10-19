# Audio and player identity

Audio assignments are authored in `scenes/audio/audio.tscn`. Select `Cues/<event>` and edit Stream, Volume dB, Pitch Scale or Enabled; the Inspector has audition/stop buttons. Filenames and supported audio formats are unrestricted by the controller. BGM and motor loops are configured through their nodes and audio import settings. The audio buses/limiter are saved in `default_bus_layout.tres`. See [the editing guide](editor.md) for the complete workflow.

Music and sound effects: **Koichi Morita / MaouDamashii (魔王魂)**, https://maou.audio/ . Used under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/); source terms: https://maou.audio/rule/ . Title menus and results use [Neorock 44](https://maou.audio/bgm_neorock44/); gameplay and pause use [Neorock 82](https://maou.audio/bgm_neorock82/). Both use the official game-loop MP3. Original files remain unchanged; playback applies gain, pitch and looping. `assets/audio/sources.json` records every URL and SHA-256.

| Source cue | Uses |
| --- | --- |
| System 08 | Nickname typing, camera gesture onset, final countdown |
| System 49 | Confirm, reconnect |
| System 18 | Back, pause, unavailable action, disconnect, buzzer |
| System 03 | Start, retry |
| System 17 | Robot switch, resume, overview |
| System 10 | Cargo selection, score, fullscreen |
| Sound 23 (roller) | Unused (motor audio disabled) |
| Sound 05 (winding) | Stair operation start |
| Sound 19/20 (metal open/close) | Manipulator start, pickup, placement, landing, brake, contact |
| Onepoint 15/14 | Win/lose, match found, Mustika |
| Onepoint 20 | Tower flip, Mustika eligibility |
| Onepoint 24 | Handover, time warning, draw |

UI inputs trigger UI cues. Competitive cues follow monotonic event IDs in authoritative snapshots; the last 64 events are retained. Audio consumes each event once, primes its cursor on reconnect, and discards events while the gameplay presentation is paused. Hover and focus changes are silent. BGM has no fade-in: playback starts at the configured volume. Each match start or reset starts gameplay BGM after one second, using the MatchStartDelay Timer in the audio scene. The outgoing track fades out for 0.35 seconds within that delay. Returning to the title/results cancels a pending gameplay start; pause/resume keeps the same track playing. Music and SFX have separate saved levels; zero mutes that bus. Four movement voices and twelve one-shot voices bound resource use. Repeated cues have short cooldowns, remote events are quieter, and continuous movement stops on pause, focus loss and match end. Missing or locked audio never delays a game command. Browser playback starts after a user gesture. Human listening and subjective mix balance remain separate from automated signal checks.

Names are generated on first visit and saved on the device. The profile editor is available from the title's name button. Names allow letters, numbers, spaces, dot, underscore and hyphen, up to 16 characters. Empty/reserved CPU names become Pilot; controls and bidi overrides are excluded. Japanese UI text uses Zen Maru Gothic Bold 700 (assets/ZenMaruGothic-OFL.txt); Dela Gothic One is reserved for speech bubbles. Names are presentation text, not account identities.

The server normalizes names on enqueue and freezes them for the assigned match. Seat tokens preserve names and ownership through reconnect and rematch. In 1v1 each player's name covers both robots. In 2v2 each seat labels its own robot. In VS CPU, the human-selected robot shows the local name; all AI-driven robots show CPU. Nameplates show only the nickname or CPU, with a team-color marker; the controlled robot uses gold lettering.

Gameplay feedback is scoped to the controlled robot: selection, work, pickup, drop, handover, placement, flip, stairs, contact, brake audio do not play for partners or opponents. Motor audio is disabled for all robots; the four Motors nodes have no stream assigned. Retry, Mustika and Mandate remain match-wide cues. Score audio follows increases in the local team's authoritative score, with a baseline refreshed during pause/reconnect.

At time-up, the presentation consumes the final snapshot, stops existing effects and motors, fades out BGM and plays `finish` once. The HUD's editable `Finish` overlay fades in with “TIME UP”. Results and their win/lose/draw cue follow after at least two seconds, or the configured finish clip's duration adjusted for pitch if longer. The result delay pauses while the application is unfocused.
