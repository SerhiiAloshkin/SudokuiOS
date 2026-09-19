# Sudoku Game

## Project Overview
iOS Sudoku game (SwiftUI + SwiftData) with 10 rule variants (Classic, Sandwich, Thermo, Arrow,
Killer, Kropki, Odd-Even, Knight's-move, King's-move, Non-Consecutive — combinable on one
level). 600 campaign levels plus a user-facing Level Builder for custom puzzles. Ad SDK
(Google Mobile Ads) removal is in progress — see "Ad SDK Removal" below for current status.

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
- **Services**: `EnvironmentConfig` (ad unit IDs — currently dead code, see below), `StoreManager`
  (IAP, `@EnvironmentObject`)
- **Known dead code**: `GameStateManager.swift`, `MoveHistoryManager.swift`, `TimerManager.swift`,
  `HintSystemManager.swift`, `GamePersistenceManager.swift`,
  `OptimizedPotentialHighlightCalculator.swift` all still exist on disk but have **zero call
  sites** — abandoned parallel implementations, not wired into `SudokuGameViewModel`. Don't
  "fix" them expecting it to affect the app; either delete them or wire them in deliberately.
  Details in the reference doc §0.

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

**Already removed** (files deleted, all call sites cleaned up — verified against the live code,
not just planning docs): `AdCoordinator.swift`, `BannerAdView.swift`,
`InterstitialAdManager.swift`. No `adCoordinator`/`AdCoordinator` references remain in any view
or view model. The hint system (`SudokuGameViewModel.useHint()`) is already ad-free — it uses a
flat 5-minute cooldown with no ad/IAP gating.

**Still remaining** (verified via grep, current as of this doc's last update):
- `SudokuiOSApp.swift` still `import GoogleMobileAds`, `import AdSupport`,
  `import AppTrackingTransparency`, and calls `MobileAds.shared.start(...)` + IDFA logging in
  `init()` — needs that block removed.
- `EnvironmentConfig.swift` still defines ad unit ID properties and imports `GoogleMobileAds` —
  **zero remaining call sites**, safe to delete outright.
- `NetworkMonitor.swift` — originally added for ad-serving connectivity checks; **zero remaining
  call sites**, safe to delete outright.
- Remove the `GoogleMobileAds` (and `AdSupport`/`AppTrackingTransparency` if unused elsewhere)
  SPM dependency from the Xcode project once the above imports are gone.
- `StoreManager.swift` still exposes the `isAdsRemoved` IAP flag — kept intentionally as a
  "Remove Ads"/"Support Development" purchase; no action needed unless product direction changes.

Before starting more ad-removal work, re-verify this list against the live files — another
session may be actively working on this in parallel; don't trust a `docs/ad-removal/*.md` status
report over the actual code.

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
