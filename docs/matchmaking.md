# Casual matchmaking

Player flow: ONLINE → 1 vs 1 / 2 vs 2 → search → MATCH FOUND → match. CANCEL leaves the search. No room creation, codes, endpoint entry or player-facing READY controls remain.

Each search has a random `ticket` and monotonically increasing `revision`. The server accepts protocol `robocon2027-v4` and ruleset `abu2027-v1.1-fixed-r4`; incompatible clients receive a reload prompt. Each format has a separate compatible pool. Within each pool, assignment is FIFO, without rank, input-device segmentation or search expansion.

Enqueue is idempotent for the same ticket/revision on a connection. Cancellation revision 2 takes precedence over a delayed revision 1 enqueue. Disconnect removes a waiting ticket. Search expires after 120 seconds; RETRY creates a fresh ticket. A group of two or four players receives an internal session identifier and individual random reconnect tokens. This identifier is not a join code and cannot be used to choose an opponent.

Clients acknowledge assignment automatically. Server authority, the 180-second clock and the 30-second reconnect grace remain unchanged. Rematch requires all assigned players; BACK returns to the title for a fresh search.

For 2v2, seats 0/1 are red/blue TR and seats 2/3 are red/blue BR. Tokens identify seats, including after reconnection. The server maps each seat to its robot rather than trusting a robot ID from input. All four acknowledgements are required before the clock starts. An assignment expires if acknowledgements are incomplete after 45 seconds. A disconnected seat gets 30 seconds to resume; expiry forfeits its team.
