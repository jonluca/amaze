# Open maze board design

The maze now follows its playable footprint instead of sitting inside a rectangular tray. Both exterior notches and enclosed blocked areas reveal the backdrop.

- A merged floor covers exactly the open cells. A separate merged grid stays visible over the paint.
- A narrow, beveled rim surrounds every closed edge, including interior holes and diagonal junctions. No wall island fills a blocked square.
- Aurora uses a dark indigo floor, lavender and pink edge highlights, and a still violet backdrop. Timber, Porcelain, and Midnight retain their own materials.
- A more top-down camera uses approximately 84–86% of the available width when height permits. Dense mazes can use more vertical space; compact and accessibility layouts still fit the complete board.
- Progress sits above the maze. Native controls, currencies, swipe handling, and game rules are preserved.
- The backdrop is not animated. Static floor, grid, rim, and channel shading use four scene nodes regardless of maze size. Paint tiles and coins retain their existing behavior.
- Large-text scrolling controls use an opaque dark background for legibility.

Included in **TestFlight 1.0.0 (6)**; see [release verification](VALIDATION.md). Visual and gameplay evidence is recorded under the ignored directory `ios/artifacts/OpenBoard/`.

## Validation, September 7, 2026

- Native build succeeds with the local Xcode simulator toolchain.
- 37 native checks passed: six actual mesh/ray tests, fifteen renderer/motion/camera checks, and sixteen save/Time Rush/blocked-move compatibility checks.
- Five gameplay UI flows passed: twenty short reversals; three automatic level advances; all four axes of angled flicks; twenty diagonal flicks plus pause/resume; and Time Rush stage transitions, pause, Journey resume, and round restart.
- The final text-contrast adjustment was rebuilt and visually checked after that suite; mesh, camera, renderer, input and core sources still match the tested source hashes.
- iPhone SE (375×667): Classic 100 has 16×16 cells and 157 playable squares. All 115 route swipes were executed through AXe. At swipe 50, the rendered accessibility state matched row 4, column 14 and 96 painted squares. Completion automatically opened level 101 at zero moves; coins increased from 550 to 615.
- iPhone 17 Pro: level 30 inspected at normal size and at the largest accessibility text size. Scrolling the dark control area left the board state unchanged.
- iPad mini: complete 16×16 level 100 inspected with all cutouts, ball, grid, and controls visible.
- Screenshot evidence in ios/artifacts/OpenBoard/: phone-level30.png, se-level100.png, se-level100-mid.png, se-level101.png, ipad-level100.png, phone-large-text.png, and phone-large-text-controls.png.
- Test evidence in the same directory: NativeAndUI.xcresult, native-ui.log, final-build.log, se-first50-proof.json, se-playthrough-proof.json, tested-source.json, and final-source.json.

Simulator checks verify appearance and input/state behavior; they do not measure physical-device ProMotion frame delivery.

## Depth and contrasting paint follow-up

The open-board design shipped in build 6. This later local pass adds more visible depth without reinstating a rectangular tray: the rim is 0.34 units above the floor with a -0.22 underside, wider bevel, approximately 22-degree camera tilt, and stronger directional/contact shading.

The selected ball skin keeps its original texture. A deterministic paint palette cycles through contrasting hues between numbered levels, accounting for patterned accents when possible. Painted tiles, splash effects and the progress indicator share that track color. Replaying the same level preserves its pairing.

Validation: 28 native checks and 3 gameplay UI flows passed in ios/artifacts/MazeDepth/NativeAndUI.xcresult. These cover all skin palettes, ball-texture preservation, pooled effects, open geometry, large-board camera clearance, rapid swipes and automatic level changes. An actual 12-swipe SE playthrough matched the expected row 11, column 1 and 28/88 painted cells. Visually inspected blue/coral level 30 on SE and teal/coral level 29 on iPhone 17 Pro.

Evidence: ios/artifacts/MazeDepth/se-level30.png, phone-level29.png, se-play-proof.json, native-ui.log and tested-source.json. Tests used build 6 plus the depth/color changes in an isolated source copy while separate tasks modified Time Rush and haptic/transition behavior. Their later integration additions to PlayView and MazeSceneRenderer are preserved; they were not part of this isolated test run.

No commit, version change or TestFlight upload was performed for this follow-up.
