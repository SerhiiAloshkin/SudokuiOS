# Sudoku Game — iOS Sudoku with 10 Rule Variants

## Project overview
iOS Sudoku game (SwiftUI + SwiftData) with 10 rule variants (Classic, Sandwich, Thermo, Arrow,
Killer, Kropki, Odd-Even, Knight's-move, King's-move, Non-Consecutive — combinable on one
level). 600 campaign levels plus a user-facing Level Builder for custom puzzles. Fully ad-free
(no ad SDK, no IAP). Localized into English, French, and Ukrainian.

**Stack:** Swift + SwiftUI · iOS 26.1 deployment target · SwiftData · `@Observable` · MVVM

## Repo layout
This folder is the git root and the Xcode project root. The two folders named `SudokuiOS` are
easy to mix up:
```
SudokuiOS/                     ← repo root (you are here): .git, SudokuiOS.xcodeproj, CLAUDE*.md, docs/
├── SudokuiOS.xcodeproj
├── SudokuiOS/                 ← app source (a synchronized Xcode group: EVERY file in it ships in the app)
│   ├── *.swift, Levels.json, Localizable.xcstrings, Assets.xcassets, Info.plist
│   └── SudokuiOSTests/        ← 12 XCTest files that are NOT wired in (see "Command line")
├── SudokuiOSTests/            ← the actual SudokuiOSTests target folder (what `xcodebuild test` runs)
├── SudokuiOSUITests/          ← XCUITest target: taps through the real app in the simulator
├── docs/                      ← reference/ (durable), archive/ (historical logs)
├── CLAUDE.md, CLAUDE-*.md     ← Claude instructions (this file + topic files)
└── Package.swift, logical_solver.py, test_logical_solver.py, run_sandwich_test.py,
    Tests/                     ← NOT part of the Xcode scheme; see "Other things at the repo root"
```
**Never put a `.md` file, script, or scratch file inside `SudokuiOS/` (the app folder)** — Xcode
picks up everything there and copies it into the app bundle. That is how `CLAUDE.md` and ~45 docs
used to end up inside the shipped `.app`.

## Build & run
```
open SudokuiOS.xcodeproj      # scheme: SudokuiOS
```

### Command line
`xcode-select` may point at Command Line Tools, so prefix with `DEVELOPER_DIR`:
```
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
DEST='platform=iOS Simulator,name=iPhone 17 Pro'
XB="xcodebuild -project SudokuiOS.xcodeproj -scheme SudokuiOS -destination \"$DEST\""
eval $XB build
eval $XB -parallel-testing-enabled NO test                                        # everything, ~2 min
eval $XB -parallel-testing-enabled NO test -skip-testing:SudokuiOSUITests         # unit tests only, ~20 s
eval $XB -parallel-testing-enabled NO test -only-testing:SudokuiOSUITests         # UI tests only
# one suite/test (Target/Suite[/test]):
#   -only-testing:SudokuiOSTests/SequentialUnlockTests
#   -only-testing:SudokuiOSUITests/SudokuiOSUITests/testEnterCorrectDigitThenUndo
```
- Use `-parallel-testing-enabled NO`: parallel runs boot cloned simulators.
- A benign `xcrun: error: unable to find utility "simctl"` line at the end of a run is xcodebuild's own diagnostics collection; ignore it.
- **What the unit-test target actually runs (verified 2026-09-20: passes, ~10 tests):** the `SudokuiOSTests` target's
  folder is the **repo-root** `SudokuiOSTests/` (`SudokuLayoutTests.swift`, plus a not-yet-committed
  `SudokuiOSTests.swift`), plus `SudokuiOS/SequentialUnlockTests.swift` (pulled in by a
  membership exception in the project). The 12 files in `SudokuiOS/SudokuiOSTests/` and the other
  `*Tests.swift` / `TestHelpers.swift` in the app folder are wrapped in `#if canImport(XCTest)`
  and compile into the **app** target, where that is false — so they **never run**. Their many
  API mismatches (see `docs/reference/CODE_MAP.md` §4) are hidden by this, not fixed.
  Don't report "all tests pass" as meaning the engine/validator suites ran.

### Run and inspect in the simulator
Build into the git-ignored `build/` folder so the `.app` path is predictable, then drive the
simulator with `simctl` (bundle id `versa.SudokuiOS`; verified working):
```
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SIM='iPhone 17 Pro'
xcodebuild -project SudokuiOS.xcodeproj -scheme SudokuiOS -destination "platform=iOS Simulator,name=$SIM" \
  -derivedDataPath build/DerivedData build
xcrun simctl boot "$SIM" 2>/dev/null; xcrun simctl bootstatus "$SIM" -b
xcrun simctl install "$SIM" build/DerivedData/Build/Products/Debug-iphonesimulator/SudokuiOS.app
xcrun simctl launch "$SIM" versa.SudokuiOS
xcrun simctl io "$SIM" screenshot <scratchpad>/shot.png    # then Read the PNG to look at the screen
xcrun simctl terminate "$SIM" versa.SudokuiOS
xcrun simctl uninstall "$SIM" versa.SudokuiOS              # wipes SwiftData/UserDefaults for a fresh start
xcrun simctl ui "$SIM" appearance dark                     # or light
```
`simctl` can launch, screenshot, reset data and switch appearance, but it **cannot tap**. Tapping is
done with XCUITest (below). `simctl uninstall` only works while the simulator is booted.
Save screenshots and scratch files outside the repo (or in `build/`) — never in `SudokuiOS/`.

### Tap through the app (UI tests)
`SudokuiOSUITests/SudokuiOSUITests.swift` launches the real app and taps through it: main menu →
Play Campaign → level 1 → Start/Continue Level → game board, enters and undoes a digit, opens
Settings. Run it with the `-only-testing:SudokuiOSUITests` command above (~1–2 min; the game screen
is slow to drive — likely the running timer keeps the app from going idle — so keep flows short).

The app has **no accessibility identifiers, launch arguments or in-memory store**, so the tests are
label-driven and share the simulator's real SwiftData store between runs:
- Find controls by visible **English** label (`app.buttons["Play Campaign"]`) or SF Symbol
  identifier (`app.buttons["gearshape.fill"]`). Board cells are *not* elements — tap them by
  coordinate (see `cell(row:col:)`); the number pad and toolbar (`Undo`, `Erase`, `Pause`…) are buttons.
- Tests must leave state as they found it and tolerate leftovers ("Continue Level" instead of
  "Start Level", a digit already in a cell). To start from scratch: boot the sim, then
  `xcrun simctl uninstall "$SIM" versa.SudokuiOS`.
- Campaign **level 1 is fixed** (`Levels.json`), so tests can use its known givens/solution.
- Tapping an already-selected cell deselects it, and a number-pad tap with nothing selected only
  shows placement highlights — select a cell once, then tap the digit.
- Don't add accessibility identifiers or launch arguments unasked (source-code change); if a test
  keeps needing a hack around this, propose adding them.

**Exploring an unfamiliar screen:** write a throwaway XCUITest that navigates there and
`print(app.debugDescription)` (dumps every element with label, identifier, frame, enabled state),
plus `try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "<scratchpad>/x.png"))`
and Read the PNG. Filter the log with `grep -E "^ *(Button|StaticText|NavigationBar),"`, then delete
the throwaway test.

## Architecture
**Pattern**: MVVM
- **Models**: `SudokuLevel` (campaign level, Codable), `CustomSudokuLevel` (SwiftData `@Model`),
  `GameSession` (active-game persistence), `SudokuCellModel` (`@Observable` per-cell state)
- **ViewModels**: `LevelViewModel` (level collection, progress, unlocking), `SudokuGameViewModel`
  (core game engine — validation, move history, hints, timer), `LevelBuilderViewModel` (custom
  level creation)
- **Views**: `MainMenuView` (`NavigationStack` root) → `SudokuGameView` (+ `SudokuBoardView`,
  `SudokuControlsView`, `SudokuHeaderView`) → overlays (Victory, pause, sandwich/killer helpers)
- **Services**: none remain (`EnvironmentConfig`, `NetworkMonitor`, `StoreManager` and
  `HintSystemManager` were deleted with the ad/IAP removal)
- **Known dead code**: five "manager" files have zero call sites — see `CLAUDE-status.md`.
  Don't "fix" them expecting an effect on the app.

## Swift conventions
- Modern SwiftUI + Swift Concurrency; async/await used sparingly (main game loop is
  synchronous with manual timer management)
- Naming: camelCase properties/methods, PascalCase types
- State: `@Published`, `@State`, `@Observable` (Swift 5.9+), `@EnvironmentObject`,
  `@StateObject`/`@ObservedObject`/`@Environment`/`@Query`
- Access control: private by default, minimal public surface
- Comments: only for non-obvious logic (validation edge cases, hint/solver algorithms)

## Read before working
- **Before scanning or grepping the codebase, read `docs/reference/CODE_MAP.md`** — a routing
  index ("task X → file Y") that also lists dead code, shadowed duplicates and which test files
  don't compile. Update it in the same commit whenever you add/move/delete/rename a file it lists.
- **`docs/reference/GAME_LOGIC_AND_RULES.md` is the source of truth** for validation, the game
  loop, hints, solving and level unlocking (derived from the code). Read it instead of re-deriving;
  update it in the same commit as any behavior change.
- **`docs/reference/GAMEPLAY_CONTROLS.md`** — exactly what each button/control does (game screen,
  Level Builder, navigation, Settings). Same rule: read first, update with behavior changes.

## Localization
English is the source language; French and Ukrainian live in one String Catalog
(`SudokuiOS/Localizable.xcstrings`). There is an in-app language switcher (Settings → Appearance →
Language), applied by a single `.environment(\.locale, …)` at the app root. Essentials:
- Literals passed to `Text("…")`, `Button("…")`, `.navigationTitle("…")` etc. localize automatically.
- **Never** use `localized(_:)` / `String(localized:locale:)` for displayed text — it doesn't honor
  the in-app language. Keep mixed-use strings as plain English catalog keys and wrap at the display
  site: `Text(LocalizedStringKey(key))`. User-generated text (custom level names) → `Text(verbatim:)`.
- Never use display text for control flow. Every new string needs `fr` and `uk` entries.

Full rules, root-cause history and worked examples: **`CLAUDE-localization.md`** — read it before
touching any user-facing text.

## Engineering policies
**Build verification**: never claim a build succeeds without actually compiling it. Run the
`xcodebuild` command above and report the real result (pass with zero errors, or the exact errors
with file:line). If you can't compile, say so ("I can't verify this builds — please run ⌘B").

**Testing**: new logic (validation, calculations, game rules, state transitions, persistence)
needs a unit test; bug fixes need a regression test. Prefer Swift Testing (`@Test`/`#expect`)
for new tests; existing XCTest suites stay as-is. Don't test SwiftUI layout directly or trivial
getters/setters. Tests must be deterministic, isolated, and fast (<1s). Put new unit tests in
the repo-root `SudokuiOSTests/` (the target's real folder) — **not** in `SudokuiOS/` or
`SudokuiOS/SudokuiOSTests/`, where they compile into the app and never run. Run them and confirm
they appear in the `xcodebuild test` output. UI flows go in `SudokuiOSUITests/`. After changing UI
(navigation, button labels, screens), run the UI tests — they are the only check that the real app
still launches and can be tapped through.

**Other standing rules**:
- Ask before changing core Sudoku validation/generation/hint algorithms in `SudokuGameViewModel`
  unless the task specifically requires it.
- Preserve SwiftData persistence (`@Model`/`@Query`) for custom levels and game sessions.
- Keep the `NavigationStack` + route-enum navigation structure intact.

## Documentation organization
- `CLAUDE.md` and `CLAUDE-*.md` (repo root) are the only instruction files. Everything else that is
  Markdown lives under `docs/` at the repo root — **never** in `SudokuiOS/` (the app folder; it
  would ship in the bundle) and never loose in the repo root.
- `docs/reference/` — durable source-of-truth docs. Update in place; don't fork dated copies.
- `docs/archive/` — historical status/plan/report logs (ad-removal, progress, build-fixes,
  optimization, testing). Read-only history: don't trust an "X is complete" claim in there over the
  live code, and don't add new status logs unless asked — put durable facts in `CLAUDE-status.md`
  or a reference doc instead.
- Xcode's built-in coding assistant can't read this file and may drop a stray `.md` in the app
  folder or repo root. When you notice one, move it into the matching `docs/` subfolder.

## Other things at the repo root
`Package.swift` (a `SudokuLogic` SwiftPM target over a subset of the app files — its `sources:`
list names files that no longer exist, e.g. `GameState.swift`), the Python reference
solver (`logical_solver.py`, `test_logical_solver.py`, `run_sandwich_test.py`), and `Tests/SudokuLogicTests/`
(stale — e.g. `AdLayoutTests`, `InterstitialFlowTests`). None of these are in the Xcode scheme.
Verify a folder is wired into the scheme before assuming its tests run.

## Quick facts
- Deployment target iOS 26.1 (`IPHONEOS_DEPLOYMENT_TARGET` in the project; older docs said iOS 17+)
- Persistence: SwiftData for levels/progress/custom levels; UserDefaults for simple flags and
  session-resume pointers
- 600 campaign levels (`Levels.json`): ids 1–250 single-variant cycling through all 10 rule types,
  ids 251–600 hybrid variants (always includes Non-Consecutive); sequential unlock with a
  full-section-1 gate before section 2 opens — exact rules in `GAME_LOGIC_AND_RULES.md` §3
- Custom levels: user-built via Level Builder, SwiftData-backed, no hard validation gate on save
  (only an advisory "human-solvable" check)

## Related files
- `CLAUDE-localization.md` — full localization rules and pitfalls
- `CLAUDE-status.md`       — dead code, ad/IAP removal status, known breakage
- `docs/reference/`        — CODE_MAP, GAME_LOGIC_AND_RULES, GAMEPLAY_CONTROLS, unlock diagram
