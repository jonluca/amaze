# Gameplay motion polish

- Level and round headings display ordinary numbers, such as **Level 16** and **Round 2**.
- The rolling trail combines an overlapping directional glow along the floor with the equipped ball's artwork. Eased fades and damped drift keep it close to the painted corridor. The existing fixed pool still caps work at 72 particles and 36 emissions per frame.
- Rolling haptic intensity increases from 0.75 to 0.90, while sharpness decreases from 0.45 to 0.30 for a deeper continuous feel. The engine retains its continuous event and existing cancellation rules; no new impact timer or gaps are introduced. Native fallback impacts use 0.90 intensity.
- Wall contact briefly compresses the ball along the slide direction, expands it across that direction, and rebounds over 0.24 seconds. A separate transform keeps the squash aligned to the wall while the ball texture rolls, preserving volume and floor contact. Queued swipes keep their existing timing; contacts crossed entirely between displayed positions do not squash the ball away from a wall.
- Each visibly completed maze gets a gold coin fan before automatic progression, including replays and each Time Rush maze. Nine prepared coins spin, lift, shrink, and fade over 0.54 seconds. Edge bursts angle inward. This is a visual celebration; the existing reward ledgers continue to determine actual coin earnings.
- The shared display clock advances trails, impacts, and completion coins, so menus and backgrounding pause them. Reset clears all three. Reduce Motion suppresses trails and squash and uses one stationary fading coin.

Simulator evidence is stored in `artifacts/MotionPolish/`. Physical haptic strength and texture require an iPhone to evaluate.

## Validation

On September 8, 2026, the dedicated iPhone 17 Pro simulator running iOS 26.5 passed 75 native tests and eight gameplay UI tests. Coverage includes all catalog trails, fixed resource budgets, wall direction and recovery at multiple display rates, completion coin timing and cleanup, Reduce Motion, haptic lifecycle, rapid swipes, three consecutive Classic completions, optimal and nonoptimal awards, Settings suspension, and Time Rush progression and restart.

`VerifiedNativeAndUI.xcresult` contains the 75 passing native tests and six passing UI tests. Two award tests initially failed on an old tab identifier; after targeting the visible Levels tab, both pass in `VerifiedAwardChecks.xcresult`. No gameplay changes were needed for that selector correction.

Visually inspected `motion-polish.png`, `ball-trails.png`, `live-gameplay.png`, and frames extracted from `gameplay.mp4`. The recording shows the gold coin fan before the perfect-solve medal and automatic board transition. `coin-completion-preview.mp4` is a short excerpt. These checks do not establish physical haptic sensation or device frame rate.
