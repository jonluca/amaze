# Coins, milestones, and spacing — September 8, 2026

The current source adds a Coin Shop from the wallet and Collection, advancing milestone goals, and a spacing pass across the app. These changes follow TestFlight build 10.

## Coin Shop

The wallet opens a sheet showing the exact balance, optional 50-coin videos, and three consumable packs. Pack prices come from StoreKit's localized `displayPrice`; an unavailable product cannot be purchased. The shop pauses gameplay and its clock, and large text stacks coin amounts and prices vertically.

| Coins | Product ID | Configured US price |
| ---: | --- | ---: |
| 1,000 | `com.jonluca.prismroll.coins.1000` | $0.99 |
| 5,500 | `com.jonluca.prismroll.coins.5500` | $4.99 |
| 15,000 | `com.jonluca.prismroll.coins.15000` | $9.99 |

App Store Connect has these three consumable records, prices, en-US metadata, US availability matching the app, and a screenshot of the implemented shop. All three were verified **READY_TO_SUBMIT** at **10:22 PM Pacific**, with exact prices and matching completed screenshot checksums. They still require [App Review before production sale](https://developer.apple.com/help/app-store-connect/configure-in-app-purchase-settings/overview-for-configuring-in-app-purchases/). Existing App Store build 8 and No Ads remain waiting for review; the app version still uses manual release. Exact provisioning readbacks are in `release/coin-packs/verification.json`.

Verified transactions deliver through `GameStore.deliverCoinPurchase`. The balance and received transaction IDs are written together to an atomic Application Support file before StoreKit finishes the transaction. Run snapshots remain in UserDefaults; the durable progress file takes precedence on launch and is written only when progress changes. Failed writes leave purchases unfinished for launch/shop recovery. A corrupt file is preserved and blocks purchase acknowledgment. Cancellation, pending approval, failed verification, and revoked transactions do not add coins. Replay of a delivered receipt does not add another credit. See [purchase implementation and limits](PrismRoll/Services/PURCHASES.md).

Videos award 50 coins only from Google's earned-reward callback. A token identifies each presentation; dismissal, stale callbacks, and duplicate callbacks cannot grant coins. Another ready video can earn another reward. No Ads continues to suppress interstitials while keeping voluntary videos available. Coins remain local to this installation, with that limitation stated in the shop.

## Advancing milestones

Three tracks generate their next goal when a reward is claimed:

- **Maze Explorer:** finish 5 levels, then 25, 50, 100, 250, 500, 1,000, and onward.
- **Against the Clock:** finish 10 Time Rush rounds, then 25, 50, 100, and onward.
- **Coin Collector:** collect 10 coins inside mazes, then 25, 50, 100, and onward. Purchased currency, videos, and reward claims do not count as maze pickups.

The sequence repeats at increasing powers of ten and does not have a finite authored final tier. Checked arithmetic prevents overflow from generating a claimable terminal reward. Reward amounts grow up to 5,000 coins per tier. Each tier has its own claim ID, so repeated taps from an old row cannot claim the next tier. Claims update inline without a blocking success alert.

Legacy `first-five`, `twenty-five`, and `timed-ten` IDs preserve old claims and unclaimed earned rewards. The two old general-completion rows merge into one track. Players who already earned an unclaimed Ball Collector reward retain a temporary claim row; new goals use the repeatable maze-pickup metric rather than requiring more balls than exist. Failed milestone saves leave the reward claimable.

## Spacing and navigation

Levels pagination uses accessible 44-point previous/menu/next icons, removing the overflowing “Earlier / Jump to / Later” word labels. Page ranges and row actions stack at larger text sizes. The wallet uses consistent icon spacing and compact toolbar formatting while VoiceOver reads the full balance. The duplicate daily-streak shortcut yields space at accessibility sizes; the streak remains in Challenges.

Settings purchase controls, daily-maze rewards, tutorial text, and gameplay headings adapt to larger text sizes. Collection and Coin Shop use native list insets and readable vertical offers. The Duel entry and Game Center section are removed from Challenges and Settings.

## Validation

- The Release engine suite passed 120 tests; the final native milestone suite covers 12 cases, including legacy migration, advancing claims, stale IDs, persistence, and failed disk writes.
- Purchase validation passed 26 unique native checks across final StoreKit, wallet, snapshot, and migration runs. StoreKit tests use Apple's local test environment, not production payments.
- Coin Shop UI tests passed purchase → spend → relaunch → purchase again, and all three offers at the largest accessibility text size. Screenshots are in `artifacts/CoinShopUI/`.
- Five unique layout/navigation UI tests passed on an isolated iPhone SE, covering compact and accessibility screens, existing ball ownership, and Coin Shop timer pause/resume. Final screenshots are in `artifacts/PaddingAudit/Screens/`.
- A real five-level milestone UI playthrough passed: **265 → 340 coins**, goal **5 → 25** inline, and the balance/next tier survived relaunch. Evidence is in `artifacts/Milestones/`.
- Two real Google SDK Debug test videos passed in the Coin Shop: **17,000 → 17,050 → 17,100 coins**, with the final balance verified after relaunch and in its saved file. Each video displayed **Test mode** and **Reward granted**. Screenshots and binary hashes are in `artifacts/CoinRewardAd/`. This verifies the actual test-ad integration; production ad serving remains unverified.
- A local unsigned Release build for physical iOS devices passed. It is a compile check, not a new TestFlight upload.

The initial purchase UI run hit an ambiguous alert selector; the final run passed after selecting the intended alert button. A concurrent perfect-move-count change required regenerating the Xcode project before final validation. Neither issue represented a coin delivery failure.
