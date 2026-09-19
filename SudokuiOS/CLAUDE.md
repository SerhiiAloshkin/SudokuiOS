# Sudoku Game

## Project Overview
iOS Sudoku game (SwiftUI + SwiftData) with 10 rule variants (Classic, Sandwich, Thermo, Arrow,
Killer, Kropki, Odd-Even, Knight's-move, King's-move, Non-Consecutive — combinable on one
level). 600 campaign levels plus a user-facing Level Builder for custom puzzles. Fully ad-free —
see "Ad SDK Removal" below for what was removed and the one remaining project-file cleanup step.

**Before scanning or grepping the codebase for a task, read `docs/reference/CODE_MAP.md`
first.** It's a routing index — "task X → file Y" — built specifically to avoid full-repo scans;
it also lists known dead code, shadowed duplicate files, and which test files currently don't
compile. Update it in the same commit whenever you add/move/delete/rename a file it references.

For the full mechanics of validation, the game loop, hints, solving, and level unlocking, treat
**`docs/reference/GAME_LOGIC_AND_RULES.md` as the source of truth** — it's derived directly
from the code and must be kept in sync with it. Don't re-derive that from scratch; read it
first, then update it in the same commit if you change behavior it describes.

## Architecture
**Pattern**: MVVM
- **Models**: `SudokuLevel` (campaign level, Codable), `CustomSudokuLevel` (SwiftData `@Model`),
  `GameSession` (active-game persistence), `SudokuCellModel` (`@Observable` per-cell state)
- **ViewModels**: `LevelViewModel` (level collection, progress, unlocking), `SudokuGameViewModel`
  (core game engine — validation, move history, hints, timer; see the reference doc),
  `LevelBuilderViewModel` (custom level creation)
- **Views**: `MainMenuView` (`NavigationStack` root) → `SudokuGameView` (+ `SudokuBoardView`,
  `SudokuControlsView`, `SudokuHeaderView`) → overlays (Victory, pause, sandwich/killer helpers)
- **Services**: none ad/IAP-related remain — `EnvironmentConfig`, `NetworkMonitor`,
  `StoreManager`, and `HintSystemManager` were all deleted (dead and/or ad-related, see "Ad SDK
  Removal" below)
- **Known dead code**: `GameStateManager.swift`, `MoveHistoryManager.swift`, `TimerManager.swift`,
  `GamePersistenceManager.swift`, `OptimizedPotentialHighlightCalculator.swift` all still exist on
  disk but have **zero call sites** — abandoned parallel implementations, not wired into
  `SudokuGameViewModel`. Don't "fix" them expecting it to affect the app; either delete them or
  wire them in deliberately. Details in the reference doc §0.

## Swift Conventions
- Modern SwiftUI + Swift Concurrency; async/await used sparingly (main game loop is
  synchronous with manual timer management)
- Naming: camelCase properties/methods, PascalCase types
- State: `@Published`, `@State`, `@Observable` (Swift 5.9+), `@EnvironmentObject`,
  `@StateObject`/`@ObservedObject`/`@Environment`/`@Query`
- Access control: private by default, minimal public surface
- Comments: only for non-obvious logic (validation edge cases, hint/solver algorithms)

## Documentation Organization Policy 📁

**The project root holds only source files, project config, and `CLAUDE.md` itself.** Every
other Markdown file — reports, plans, checklists, summaries, diagrams — goes under `docs/`, in
the matching subfolder. Never create a `.md` file in the repo root or in `SudokuiOSTests/`.

```
docs/
├── ad-removal/   AdMob/GoogleMobileAds removal: plans, changes, cleanup notes
├── build-fixes/  Build error diagnosis and fix write-ups
├── optimization/ Performance/optimization reports
├── progress/     Phase/step logs, task summaries, "ready to commit" notes
├── reference/    Durable source-of-truth docs (GAME_LOGIC_AND_RULES.md, UNLOCK_SYSTEM_DIAGRAM.md)
│                 — update in place, don't fork a new dated file when behavior changes
└── testing/      Test plans, test-fix write-ups, testing checklists
```

Pick the subfolder that matches the doc's topic; if none fits, propose a new one under `docs/`
rather than defaulting to the root. Reference docs get updated in place; status/progress/plan
docs are historical logs and are fine to accumulate in their subfolder.

**Known gap**: Xcode's built-in Coding Intelligence assistant (the model picker in Xcode
Settings, as opposed to Claude Code) has no mechanism to read this file, so it won't follow this
policy and may drop a `.md` file at the root of either `SudokuiOS/` (this folder) or the outer
repo root (`/SudokuiOS/`, one level up, where `.git`/`SudokuiOS.xcodeproj` actually live — note
the two folders share a name, easy to mix up). This is expected, not a bug to chase — when a
Claude Code session notices a stray root-level `.md`, sweep it into the matching `docs/`
subfolder as routine cleanup (as happened with `HIGHLIGHT_TIMING_FIX.md` → `docs/build-fixes/`).

## Ad SDK Removal — Current Status

**Complete as of 2026-09-19** (verified against the live code, not just planning docs — re-verify
before trusting this if it's been a while, since another session has previously worked on this in
parallel; don't trust a `docs/ad-removal/*.md` status report over the actual code):

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
- Remove the `GoogleMobileAds` SPM dependency from the Xcode project itself (`project.pbxproj`
  package references) — this is the one piece that can't be done from a text-editing pass; needs
  Xcode or manual `.pbxproj` surgery.

## Engineering Policies

**Build verification**: never claim a build succeeds without actually compiling it. If you can't
compile, say so explicitly ("I can't verify this builds — please run ⌘B") instead of "should
work." If you can compile, report the actual result (pass with zero errors, or the exact
remaining errors with file:line).

**Testing**: new logic (validation, calculations, game rules, state transitions, persistence)
needs a unit test; bug fixes need a regression test. Prefer Swift Testing (`@Test`/`#expect`)
for new tests; existing XCTest suites stay as-is. Don't test SwiftUI layout directly or trivial
getters/setters. Tests must be deterministic, isolated, and fast (<1s).

**Other standing rules**:
- Ask before changing core Sudoku validation/generation/hint algorithms in `SudokuGameViewModel`
  unless the task specifically requires it.
- Preserve SwiftData persistence (`@Model`/`@Query`) for custom levels and game sessions.
- Keep the `NavigationStack` + route-enum navigation structure intact.

## Quick Facts
- iOS 17+ (uses `@Observable`, SwiftData, modern SwiftUI)
- Persistence: SwiftData for levels/progress/custom levels, UserDefaults for simple flags and
  session-resume pointers
- 600 campaign levels (`Levels.json`): ids 1–250 single-variant cycling through all 10 rule
  types, ids 251–600 hybrid variants (always includes Non-Consecutive); sequential unlock with a
  full-section-1 gate before section 2 opens — see reference doc §3 for exact rules
- Custom levels: user-built via Level Builder, SwiftData-backed, no hard validation gate on save
  (only an advisory "human-solvable" check)
