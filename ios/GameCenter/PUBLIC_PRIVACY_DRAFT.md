# Public privacy update for the Game Center release

Publish this section at `https://thoughtahead.com/prism-roll/privacy.html` with
the future build that includes this Game Center integration. The currently
submitted build 14 does not include it. The corresponding in-app policy section
is already in `PrivacyPolicyView.swift`.

## Game Center

If you sign in to Apple's Game Center, Prism Roll sends achievement progress and
completed-maze scores to Apple. Your Game Center profile and scores may be visible
to other players according to your Game Center settings. The app keeps a local
report queue associated with your game-specific player identifier so saved progress
can sync after a connection failure. Your first Game Center account on this
installation can receive your existing local progress; switching accounts keeps
their new earned progress separate.

The Apple Games app can open Classic, Time Rush, or the daily maze. Game Center
does not back up or restore your maze saves, coins, or collection. You can continue
playing solo while signed out and manage Game Center sign-in, your profile, and
sharing through iOS Settings. Game Center identifiers and profile names are not
sent to Google Analytics or Crashlytics.

Add [Game Center & Privacy](https://www.apple.com/legal/privacy/data/en/game-center/)
to the provider privacy links. Retain the existing analytics, crash-report,
advertising, purchase, and local-save disclosures. Reconcile the version's App
Store privacy answers with the final shipping behavior during that release.
