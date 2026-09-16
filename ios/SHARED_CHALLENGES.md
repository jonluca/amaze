# Shared puzzles and review requests

## Challenge links

Version 1 links use `https://thoughtahead.com/prism-roll/challenge/?v=1&p=…`.
The app also accepts `prismroll://challenge?v=1&p=…` for the landing page's
explicit **Open in Prism Roll** action. Universal-link association belongs to
`F35YQQ5672.com.jonluca.prismroll`; deployment and signing verification are
separate from the native decoder tests.

`p` is unpadded base64url of UTF-8 JSON:

| Key | Meaning |
| --- | --- |
| `w`, `h` | Integer width and height, each 2–16 |
| `s` | Starting square, indexed as `row * w + column` |
| `o` | Exactly `w * h` ASCII `0`/`1` occupancy characters in row-major order |
| `t` | Nonempty display title, at most 80 characters, no control characters |
| `m` | Optional sender move count, 1–100,000 |
| `r` | A legal covering route, 1–2,048 ASCII `U`/`D`/`L`/`R` moves |

The native decoder bounds the URL to 8,192 UTF-8 bytes, the encoded payload to
6,000 bytes, and decoded JSON to 4,096 bytes before parsing. It rejects unknown
versions, other origins, extra/duplicate query parameters, invalid starts,
blocked solution moves, and routes that fail to cover the grid. It does not run
an optimizer on untrusted link input. The actual grid and covering route travel
with the link, so a later generator change cannot change the puzzle.

Links are casual challenges, not authenticated scores. The route is intentionally
included to validate playability; it is not a secret or a ranked competition.
Neither the payload nor the sender's score grants currency or normal progression.

## Native flow

- Challenges can share today's puzzle and include the completed daily score when
  its saved completed run is available.
- Completed Classic and Limited Moves rows can share their puzzle. A saved score
  is included only when its recorded geometry matches the linked board.
- `ChallengeShareCard` draws the actual grid and start square; the system share
  sheet includes that image, the message, and the HTTPS link.
- `SharedChallengeSession` owns a separate `MazeRun`. It does not receive a
  `GameStore`, wallet, UserDefaults, or progression object. All levels are playable
  in this session regardless of the recipient's normal unlock progress.
- The existing game is paused while the challenge is presented. Dismissing it
  resumes the untouched normal/daily run. Shared puzzles have unlimited moves,
  no timer, no completion coins, and a persistent result with replay/share actions.
- Incoming links wait for consent, ads, rewards, and other sheets to finish.
  Shared play does not start an ad preparation request.

Events are `challenge_share_opened`, standard `share` after the system share
sheet reports completion, `challenge_opened`, `challenge_started`, and
`challenge_completed`; screens use `shared_challenge`. These use the existing
analytics consent. Link contents and challenge titles are not sent as events.
A share-sheet completion does not prove a recipient opened the content or installed.

## Review requests

`ReviewPromptPolicy` requires ten completed regular levels and engagement on
three distinct calendar days. Subsequent requests require ten further
completions, 120 days since the last request, and fewer than three requests in the
previous 365 days. It does not inspect sentiment, purchases, predicted ratings,
or ad behavior. Eligibility and requests persist separately from game saves.

The app asks StoreKit when an eligible player voluntarily navigates away from
Play, with no other sheet active. Automatic level advancement remains unchanged.
The request is recorded even if Apple's system does not display its sheet.
There is no reward or custom rating pre-prompt, and UI-test launches suppress it.

## Verification

`ChallengeLinkTests` covers real-board and daily-board round trips, actual-grid
stability, custom/HTTPS link parity, hostile schemas, unknown versions/origins,
and invalid/unsolvable routes. `ReviewPromptPolicyTests` covers engagement,
cooldowns, serialization, backward clocks, and annual request limits.

`SharedChallengeSessionTests` covers solving a locked shared puzzle without
touching solo/daily saves or currency across relaunch, timed-run pause/resume,
stale gesture invalidation, and review-request persistence.

Pure checks: `swift test --package-path ios/EnginePackage --filter
'ChallengeLinkTests|ReviewPromptPolicyTests'`. The shared-session tests require
the iOS test target. Device verification must also exercise actual incoming links,
share-sheet presentation, and universal-link association after website deployment.
