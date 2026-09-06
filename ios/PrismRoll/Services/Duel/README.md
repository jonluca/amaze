# Game Center Duel

This service uses real `GKMatchmakerViewController` / `GKMatch` peer networking and has no simulated rivals. GameKit APIs were checked against the installed iPhoneSimulator27.0 SDK headers.

Call `authenticate()` when the user opens Duel. After sign-in, `findMatch()` presents Apple's two-player matchmaking UI. The registered local-player listener can also receive accepted invitations. `status` explains unavailable sign-in, matchmaking, and connection failures; solo play remains available.

Observe `seed` and `matchID`, or set `onStart(seed, matchID)`. Generate `MazeLevel.generate(number: seed, mode: .endless)` in a separate unsaved duel run. Call `sendProgress(painted:total:moves:)` immediately after starting and after each move. After a completed maze's final progress update, call `submitCompletion()`. Observe `didWin` or `onFinish(won)`. Do not grant currency, unlock solo levels, or mutate solo saved games from duel events.

Call `cancel()` when leaving Duel or entering the background. An interrupted match is abandoned, never resumed or awarded as a win. The result connection stays alive until leaving to allow reliable delivery. `playerGroup = 1` identifies the generator/protocol version and must change if either becomes incompatible.

The lexicographically first Game Center player ID is the host. The host proposes a random seed and UUID, waits for the other peer's readiness, and starts both copies of the maze. The host resolves the first completion it processes and sends that result reliably. Inputs are bounded, tied to the actual GameKit sender and current match, and progress must be monotonic with matching cell counts. This provides a casual peer-hosted race, not server-authoritative anti-cheat or latency-neutral ranked competition. It intentionally has no monetary or coin rewards.

Before release: enable Game Center for the bundle ID and App Store Connect app, sign the matching entitlement, and test with two distinct authenticated accounts on two devices. Validate invites, automatching, same board, completion, simultaneous finish, disconnect, and background cancellation. Two-account networking is **not verified** by a simulator build or a single-account authentication attempt.
