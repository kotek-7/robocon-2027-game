# Casual matchmaking

Player flow: ONLINE → FINDING PLAYER → MATCH FOUND → match. CANCEL leaves the search. No room creation, codes, endpoint entry or player-facing READY controls remain.

Each search has a random `ticket` and monotonically increasing `revision`. The server accepts protocol `robocon2027-v2` and ruleset `abu2027-v1.1-fixed-r3`; incompatible clients receive a reload prompt. Within this one compatible pool, assignment is FIFO, without rank, input-device segmentation or search expansion.

Enqueue is idempotent for the same ticket/revision on a connection. Cancellation revision 2 takes precedence over a delayed revision 1 enqueue. Disconnect removes a waiting ticket. Search expires after 120 seconds; RETRY creates a fresh ticket. A matched pair receives an internal session identifier and individual random reconnect tokens. This identifier is not a join code and cannot be used to choose an opponent.

Clients acknowledge assignment automatically. Server authority, the 180-second clock and the 30-second reconnect grace remain unchanged. Rematch requires both players; BACK returns to the title for a fresh search.
