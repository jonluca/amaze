# Research-informed UX pass

Reviewed 6 September 2026. These changes are local; they have not been uploaded to App Store Connect.

## Guidance applied

| Primary guidance | Change in Prism Roll |
| --- | --- |
| [Apple: Onboarding for Games](https://developer.apple.com/app-store/onboarding-for-games/) recommends short contextual teaching, immediate play, optional tutorials, and a reference players can revisit. | The first unfinished Classic maze teaches wall movement, then the painting objective after a valid move. Tips can be hidden permanently. Hints on that first maze are free; finishing it retires the allowance, including on replay. Pause includes a short guide. |
| [Apple: Design advanced games for Apple platforms](https://developer.apple.com/videos/play/wwdc2024/10085/) discusses broad touch areas, feedback, and readable controls that adapt to available space. | Broad swipes remain available. Blocked directions give an inline explanation and a softer optional haptic without consuming a move. Compact layouts scroll optional controls while retaining a playable board. |
| [Microsoft XAG107: Input](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107) recommends alternatives to path-based gestures and single-press input. | Optional native direction buttons provide named tap targets and arrow-key shortcuts. A tap commits once, and stale or paused input is rejected. The preference survives relaunch and older saves migrate safely. |
| [Microsoft XAG108: Difficulty](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/108) recommends pausing single-player games. | A dedicated native Pause sheet freezes Time Rush and retains paint, moves, and remaining time. Live Duel does not offer pause. Classic remains available without a time or move limit. |
| [Apple: Differentiate Without Color](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilitydifferentiatewithoutcolor) identifies when the user needs alternatives to color-only distinctions. | System-enabled outlined rings identify unfinished cells. Each disappears when the visible ball actually paints that tile, including during queued slides and live setting changes. |
| [Google: Rewarded ads](https://developers.google.com/admob/ios/rewarded) and [Interstitial ads](https://developers.google.com/admob/ios/interstitial) cover earned callbacks, preloading, natural transition points, and avoiding excessive interruptions. | Reward controls disclose ready, loading, and unavailable states. Missing inventory retries inline without freezing gameplay or showing an error alert. Successful ads refill promptly; failed loads retain a retry cooldown. Automatic ads require four completions and at least 90 seconds since the last ad was dismissed. The 90-second interval is a product choice, not a Google requirement. |

## Validation

Validation results and simulator screenshots are recorded under `artifacts/ResearchUX/`. Both native-suite runs passed all 103 tests, covering existing gameplay and rewards plus the new coaching, controls, migration, ad-policy, and rendering regressions.

- `Tests.xcresult`: initial iPhone 17 Pro run; 103 native tests passed, 13 of 16 UI flows passed. It exposed two tutorial identifier failures and a purchase-test scroll overshoot.
- `FinalCompactTests.xcresult`: iPhone SE; 103 native tests passed, six of eight selected UI flows passed, including free hints without the Debug hint bypass, timer pause/resume, fast flicks, progression, large text, and local StoreKit purchase/restore/refund. Two UI-driver issues remained: overshooting a large-text button and tapping the Settings row instead of its switch. The command was stopped after results were written because its process lingered.
- `VerifiedControlsTests.xcresult`: a fresh test build passed all four selected UI tests: maximum accessibility text, free introductory hints, native direction buttons and saved preference, and timer pause/resume. The test now targets the native switch and uses short scroll strokes. Across these runs, every one of the 16 distinct UI scenarios has a passing result.
- `FinalDirectionLayout.xcresult`: the native-controls flow passed again after reducing horizontal spacing. Its [final SE capture](artifacts/ResearchUX/se-final-direction-buttons.png) confirms that all four directions fit together at standard text size.

Manual checks on iPhone SE and iPhone 17 Pro verified the system Differentiate Without Color setting, keyboard movement and its pause guard, board layout, and Google test ads. One test video delivered a hint; another added 30 seconds to an already started Time Rush run. The resulting pause screen showed 56 seconds remaining. Inventory refilled after the first video. These were Google's test ad units, not production traffic.

Representative captures: [first maze](artifacts/ResearchUX/iphone17-final-first-level.png), [optional controls](artifacts/ResearchUX/iphone17-controls.png), [keyboard movement](artifacts/ResearchUX/keyboard-down.png), [large text](artifacts/ResearchUX/13-accessibility-text.png), and [rewarded time extension](artifacts/ResearchUX/test-ad-time-extension-paused.png).

Simulator testing found and fixed two integration issues: tutorial completion could reconstruct the compact board before the final slide finished, and a parent accessibility identifier masked the Hide tips button's identifier. Tutorial presentation now remains stable through completion. Review also closed a timer-expiry race at Pause. Visual inspection led to brighter reward captions and tighter horizontal direction-button spacing so all four fit on a standard-text iPhone SE.

Physical-device touch latency, Voice Control, Switch Control, and production ad delivery require device/service testing. Simulator tests do not establish those results. No new telemetry or advertising SDK was added.
