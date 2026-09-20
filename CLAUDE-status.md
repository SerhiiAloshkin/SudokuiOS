# Sudoku Game — Status, Dead Code and Known Breakage

Things that are true about the codebase right now but can't be read off the code at a glance.
Verify against the live code before relying on any of it — it's a snapshot, and earlier
sessions have worked on this in parallel.

## Known dead code
`GameStateManager.swift`, `MoveHistoryManager.swift`, `TimerManager.swift`,
`GamePersistenceManager.swift`, `OptimizedPotentialHighlightCalculator.swift` all still exist on
disk but have **zero call sites** — abandoned parallel implementations, not wired into
`SudokuGameViewModel`. Don't "fix" them expecting it to affect the app; either delete them or
wire them in deliberately. Details in `docs/reference/GAME_LOGIC_AND_RULES.md` §0 and the traps
list in `docs/reference/CODE_MAP.md` §3.

## Ad SDK Removal — Current Status

**Complete as of 2026-09-19** (verified against the live code, not just planning docs — re-verify
before trusting this if it's been a while, since another session has previously worked on this in
parallel; don't trust a `docs/archive/ad-removal/*.md` status report over the actual code):

- `AdCoordinator.swift`, `BannerAdView.swift`, `InterstitialAdManager.swift`,
  `EnvironmentConfig.swift`, `NetworkMonitor.swift` — deleted. No `adCoordinator`/`AdCoordinator`
  references remain anywhere.
- `SudokuiOSApp.swift` — `GoogleMobileAds`/`AdSupport`/`AppTrackingTransparency` imports and the
  `MobileAds.shared.start(...)` + IDFA-logging init block removed.
- `Info.plist` — `GADApplicationIdentifier` and the ~55-entry `SKAdNetworkItems` array removed.
- The hint system (`SudokuGameViewModel.useHint()`) was already ad-free (flat 5-minute cooldown,
  no ad/IAP gating).
- **The "Remove Ads" IAP was removed entirely, not just its ad-related copy** — this was a
  deliberate product decision (explicitly confirmed), not just dead-code cleanup, because the
  purchase button had already been silently dropped from `SettingsView.swift` in an earlier pass
  while `StoreManager.swift` kept auto-restoring the flag for past purchasers, and that flag also
  unlocked all 600 levels (independent of ads) via `LevelViewModel`'s unlock algorithm. Deleted:
  `StoreManager.swift`, `HintSystemManager.swift` (dead + carried a rewarded-ad-shaped API),
  `AppSettings.didPurchaseRemoveAds`, `LevelViewModel.hasRemovedAds` and its "remove-ads unlocks
  everything" unlock rule (was Rule 3 in `recalculateLocks`). **Effect on existing customers**:
  anyone who previously purchased "Remove Ads" no longer gets automatic full-level access from
  that entitlement — levels now unlock only via normal sequential progression or the debug
  override. If this needs to be revisited (e.g. a real App Store Connect refund/support
  obligation), that's a product decision, not a code one — flag it back to the user, don't just
  restore the mechanic.
- Two Encyclopedia entries in `HowToPlayView.swift` ("Remove Ads", "Restore Purchases") removed
  to match — they described a purchase flow that no longer exists.
- `SequentialUnlockTests.swift` updated to drop the `hasRemovedAds` parameter and its "Remove Ads
  IAP unlocks all levels" test case. Three already-broken test files
  (`UnlockingLogicTests.swift`, `SudokuiOSTests/LevelSelectionTests.swift`,
  `SudokuiOSTests/LevelManagerTests.swift`) still reference the now-fully-removed
  `isAdUnlocked`/`unlockLevelViaAd` — not newly broken by this change, but now doubly stale; see
  `docs/reference/CODE_MAP.md` §4.
- The `GoogleMobileAds` SPM dependency is removed from the Xcode project itself
  (`project.pbxproj`'s `PBXBuildFile`, `PBXFrameworksBuildPhase`, `packageProductDependencies`,
  `packageReferences`, `XCRemoteSwiftPackageReference`, and `XCSwiftPackageProductDependency`
  entries) — done via manual `.pbxproj` surgery (validated with `plutil -lint`). **Note**:
  `SudokuiOS.xcodeproj` used to be `.gitignore`'d, so this edit was never committed; the project
  file is now tracked (see `.gitignore`), so it shows up in the next commit. Ad SDK removal is now fully complete, including the project-file cleanup that
  was previously the one remaining piece.
