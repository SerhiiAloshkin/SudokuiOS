# Code Map — Where Things Live

**Purpose**: consult this before grepping or reading broadly to find code for a task. It answers
"which file(s) do I need for X" so you don't have to scan the repo. For *how the logic actually
behaves* (validation rules, game-loop mechanics, unlock algorithm, hint system), go to
`GAME_LOGIC_AND_RULES.md` in this same folder. For *what every button/control does, exactly* (game
screen, Level Builder, navigation, Settings), go to `GAMEPLAY_CONTROLS.md` in this same folder.
This doc is the index, the other two are the manuals.

Keep all three updated in the same commit as any change they describe.

---

## 1. Quick Routing Table

| Your task is about... | Start here | Notes |
|---|---|---|
| A specific rule variant's validation (Classic/Sandwich/Thermo/Arrow/Killer/Kropki/Odd-Even/Knight/King/Non-Consecutive) | `SudokuValidator.swift` (`validateXxx` functions) | Exact semantics/edge cases: `GAME_LOGIC_AND_RULES.md` §1 |
| Move entry, mistake counting, undo/redo, notes/pencil-marks, win detection, timer, save/load | `SudokuGameViewModel.swift` | The single 2865-line engine file. Details: `GAME_LOGIC_AND_RULES.md` §4 |
| Hint button behavior / cooldown | `SudokuGameViewModel.useHint()` | `HintSystemManager.swift` was a dead, ad-shaped duplicate — deleted 2026-09-19 |
| "Valid placement" cell highlighting | `PotentialHighlightCalculator.swift` | **Not** `OptimizedPotentialHighlightCalculator.swift` — dead file, zero call sites |
| Level unlock rules / sequential progression / the 250↔251 barrier | `LevelViewModel.recalculateLocks(...)` | Exact algorithm: `GAME_LOGIC_AND_RULES.md` §3.2 |
| Level list filtering/sorting (by solved state or rule type) | `LevelSelectionViewModel.swift` (`LevelFilter` enum) | Filters match only a level's *primary* `ruleType`, not hybrid `types` |
| Locked-level messaging / the pre-play sheet | `LevelPreviewModal.swift` | Also where the 250/251-barrier UI copy branches |
| Board rendering, cell layout, drag-to-select gesture | `SudokuGameView.swift` (`SudokuBoardView` nested struct, ~L924-1173) | Drag-select logic lives in the view, not the view model |
| Per-variant board decoration (arrows, cages, dots, thermo, odd/even frames) | `ArrowDrawingView.swift`, `KillerCageLayer.swift`, `KropkiLayer.swift`, `OddEvenLayer.swift`, `SudokuBoardComponents.swift` (`ThermoOverlay`) | Pure renderers — no validation logic in any of these |
| Victory screen | `VictoryOverlayView.swift` | This top-level file *is* the live one |
| Game-over screen (3-mistake limit reached) | `GameOverOverlayView.swift` | Fixed 2026-09-19: was previously shadowed by a duplicate nested struct in `SudokuGameView.swift`; that duplicate is now removed |
| App navigation / adding a new screen | `MainMenuView.swift` (`SudokuRoute` enum + `navigationDestination`) | The single source of navigation truth for the whole app |
| Settings screen / a specific toggle not persisting | `SettingsView.swift` + `AppSettings.swift` | Mixed persistence — check both SwiftData property *and* `@AppStorage`, see §3 |
| Level Builder tool logic (thermo/arrow/cage drawing rules, save behavior) | `LevelBuilderViewModel.swift` | `LevelBuilderView.swift` is almost pure rendering — logic lives in the view model |
| Custom level persistence / progress restore on reopen | `CustomSudokuLevel.swift` (`toSudokuLevel()`) + `CustomGameWrapperView.swift` | Copy happens in `.onAppear`, deliberately not `body` (avoids re-render loops) |
| In-app rules/tutorial text for a variant | `RulesView.swift` **and** `HowToPlayView.swift` | Two independently-maintained copies of the same rule text — keep both in sync |
| What a specific button/control does, exactly | `GAMEPLAY_CONTROLS.md` | Exhaustive per-control reference across the game screen, Level Builder, navigation, and Settings — check here before re-deriving from the view code |
| Adding/changing any user-facing string, or anything about localization | `Localizable.xcstrings` (in `SudokuiOS/`) + `CLAUDE-localization.md` | Read `CLAUDE-localization.md` first — it covers the `LocalizedStringKey` vs. `String(localized:)` decision, format-specifier keys for interpolated strings, and a real string-equality-as-control-flow bug it fixed |
| Anything ads or IAP-related | `CLAUDE-status.md` → "Ad SDK Removal" section | **Fully removed as of 2026-09-19** — no ad SDK, no IAP, no `StoreManager`/`EnvironmentConfig`/`NetworkMonitor`. Don't add code assuming any of these exist. |
| Killer/Sandwich digit-combination helper popup | `KillerHelperView.swift`/`SandwichHelperView.swift` (display only) + `KillerMath.swift`/`SandwichMath.swift` (the actual combination math) | |
| Writing or fixing a unit test | §4 (Test Map) below **first** | Most existing test files don't compile — don't copy their patterns without checking this table |

---

## 2. File Index by Domain

### Game Engine (core logic — not UI)
- `SudokuGameViewModel.swift` — the engine: board state, move validation, mistakes, undo/redo, notes, hints, timer, save/load. One giant file, single source of truth.
- `MoveHistory.swift` — SwiftData move-record model (real undo/redo backing store)
- `GameSession.swift` — lightweight Codable "resume" pointer (UserDefaults-backed)
- `UserLevelProgress.swift` — SwiftData per-campaign-level progress model
- `SudokuCellModel` (defined inside `SudokuGameViewModel.swift`) — `@Observable` per-cell state, the real board-state source of truth

### Rule Validation
- `SudokuValidator.swift` — `validate(board:rules:) -> Bool` entry point + one `validateXxx` per variant
- `SudokuRuleType.swift` — display/metadata enum (`classic`/`sandwich`/etc.) + multi-rule string parsing (`allRules(from:)`)
- `KillerMath.swift`, `SandwichMath.swift` — digit-combination generators for the helper UI/level builder (not live validation)
- `PointingPairsSolver.swift` — hint/highlight-restriction solver; **duplicates** Kropki/knight/king/classic constraint math independently of `SudokuValidator` — no confirmed call site found, verify before relying on it
- `LevelVariantHelper.swift` — tutorial-only restricted-cell highlighting (knight/king only)

### Solver & Hints
- `HumanLogicSolver.swift` — level-builder-only "is this solvable" advisory check (`LevelBuilderViewModel.checkValidation()`); not used for live hints
- `PotentialHighlightCalculator.swift` — **live** "valid placement" highlight algorithm
- `HighlightManager.swift` — knight/king offset constants (one of 3 duplicate copies in the codebase — see §3)
- `OptimizedPotentialHighlightCalculator.swift` — dead, still present, see §3. (`HintSystemManager.swift` was the same kind of dead file but has been deleted — see "Ad SDK Removal" in `CLAUDE-status.md`.)

### Levels: Campaign, Selection, Unlocking
- `LevelViewModel.swift` — level collection, SwiftData progress, the sequential-unlock algorithm (`recalculateLocks`)
- `LevelSelectionView.swift` + `LevelSelectionViewModel.swift` — campaign grid UI + filter/sort
- `LevelPreviewModal.swift` — pre-play sheet, restart, 250/251-barrier messaging
- `LevelPreviewBoard.swift` — read-only clue-only preview renderer (reuses the same overlay components as live gameplay — keep in sync if you change variant rendering)
- `LevelIconsInfoView.swift` — static rule-icon legend, hardcoded

### Custom Levels & Level Builder
- `CustomSudokuLevel.swift` — SwiftData model + `toSudokuLevel()` adapter into the campaign-level shape
- `CustomLevelsListView.swift` — `@Query`-backed list, direct delete (no confirmation)
- `CustomGameWrapperView.swift` — wires a `CustomSudokuLevel` into the normal game engine
- `LevelBuilderView.swift` — builder UI/rendering (~640 lines, nearly no logic)
- `LevelBuilderViewModel.swift` — **actual builder logic**: tap handling, shape/adjacency rules, save (no hard validation gate on save)
- `BuilderMessageOverlayView.swift` — generic modal, no builder-specific logic

### Board & Gameplay UI
- `SudokuGameView.swift` — screen composition root: header, board, controls, toolbar, alerts/sheets, scene-phase timer wiring. Contains many nested types (`SudokuCellView`, `SudokuHeaderView`, `SudokuControlsView`, `SudokuBoardView`, pause/sandwich/killer overlays, `HintButtonView`, `ColorPickerView`). Its game-over overlay is the top-level `GameOverOverlayView.swift` (a previously-shadowing nested duplicate was removed).
- `SudokuBoardComponents.swift` — `PreviewSudokuCellView` (standalone preview cell), `SudokuBoardOverlay` (3x3 box lines), `ThermoOverlay`
- `ArrowDrawingView.swift` — Canvas renderer for arrows (bulb + line + arrowhead geometry)
- `KillerCageLayer.swift` — cage outline renderer; contains a real perimeter-tracing algorithm (marching-squares-style), not simple rendering
- `KillerHelperView.swift`, `SandwichHelperView.swift` — combination-helper modals (display/sort only)
- `KropkiLayer.swift` + `KropkiBorder.swift` — dot renderer; takes a precomputed `errorBorders` set, doesn't compute it
- `OddEvenLayer.swift` — parity-frame renderer, parses the 81-char parity string directly
- `NumberPadView.swift` — 1-9 input buttons, all logic via closures back to the caller
- `VictoryOverlayView.swift` — live victory screen (pure presentation; next-level *decision* is made by `SudokuGameView.getNextLevelInfo()` and passed in)
- `GameOverOverlayView.swift` — the live game-over screen (matches `VictoryOverlayView.swift`'s visual style: `.ultraThinMaterial`, spring appear animation, gradient title)

### Rules / Tutorial UI
- `RulesView.swift`, `HowToPlayView.swift` — two separately-maintained in-app rule explanations. `RulesView` (the in-game "How to Play" sheet, per-variant rule cards) now has a "Full Guide" button opening `HowToPlayView` (the "Versa Encyclopedia," previously reachable only from the Main Menu) — added 2026-09-19 so Encyclopedia content is reachable mid-game.
- `RulesListView.swift` — compact rule-badge row (icon+text → icons-only → scrollable), used by preview/list screens
- `SudokuRuleTagView.swift` — tag/badge color mapping per variant

### Navigation & App Shell
- `SudokuiOSApp.swift` — `@main` entry point, SwiftData `ModelContainer` setup, DI root. No ad SDK code remains here (removed 2026-09-19).
- `MainMenuView.swift` — owns the app's only `NavigationStack` and the `SudokuRoute` enum (the single source of navigation truth); also the home screen UI and "Continue" card
- `SplashView.swift` — loading animation + kicks off level data load, no business logic

### Settings, Theming
- `SettingsView.swift` — all user-facing toggles, bound to `AppSettings` (SwiftData) plus a couple of legacy `@AppStorage` keys directly. No purchase/IAP UI (removed).
- `AppSettings.swift` — SwiftData settings model + enums (`HighlightMode`, `MistakeMode`, `HintTarget`, `AppTheme`); several properties silently bridge to `UserDefaults` instead of SwiftData, see §3
- `ThemeColors.swift`, `ButtonStyles.swift` — pure style utilities, no state

### Misc UI Chrome (rendering only, no logic)
- `SudokuLogoTitleView.swift`, `SudokuPreviewGrid.swift`, `WatermarkBackgroundView.swift`, `MailView.swift` (thin `MFMailComposeViewController` wrapper for Settings' contact-support flow)

---

## 3. Known Traps (check here before you waste a turn)

1. ~~`GameOverOverlayView.swift` was dead/shadowed by a nested duplicate in `SudokuGameView.swift`.~~ **Fixed 2026-09-19** — the nested duplicate (which had stale, off-brand styling: plain black overlay, no animation, hardcoded colors) was deleted from `SudokuGameView.swift`; `GameOverOverlayView.swift` is now the single, live implementation and its call site (`SudokuGameView.swift:176`) resolves to it. If a game-over-screen bug report still doesn't match what you see in `GameOverOverlayView.swift`, re-check for a reintroduced duplicate before assuming this file is wrong.
2. **Five "manager" classes are unused parallel implementations**, not wired into `SudokuGameViewModel`: `GameStateManager.swift`, `MoveHistoryManager.swift`, `TimerManager.swift`, `GamePersistenceManager.swift`, `OptimizedPotentialHighlightCalculator.swift`. All real behavior for these responsibilities is inline in `SudokuGameViewModel.swift` / `PotentialHighlightCalculator.swift`. Confirm via `/usr/bin/grep` (not bare `grep` — see below) before assuming any of these affect the running app. (A sixth, `HintSystemManager.swift`, was the same kind of dead file but carried an ad-shaped API and was deleted on 2026-09-19 during ad/IAP removal.)
3. **`AppSettings` has mixed persistence.** Most flags are real SwiftData stored properties; `hintAppliesToSelectedCell`, `nextHintAvailableDate`, `isMistakeLimitEnabled`, and `showHintButton` are computed properties that silently bridge to `UserDefaults` instead. If a setting isn't persisting as expected, check which mechanism that specific property actually uses. (`didPurchaseRemoveAds` used to be one of these — removed along with the IAP it backed.)
4. **Knight/king offset arrays are duplicated in 3+ places**: `HighlightManager.swift`, an inline literal in `PotentialHighlightCalculator.swift`, and `SudokuValidator.validateKnight`/`validateKing`. Kropki white/black/negative-constraint math is duplicated between `SudokuValidator.validateKropki` and `PointingPairsSolver.swift`. Classic row/col/box legality exists in at least 3 separate hand-written copies. Any rule-math change must be hunted down in all copies — grep for the constant/logic pattern, don't assume one file is the only place.
5. **The shell's `grep`/`find` builtins can be broken/shadowed** by a bad shell snapshot function in this environment (produces a spurious "claude native binary not installed" error). If a plain `grep`/`find` call errors like that, retry with `/usr/bin/grep`/`/usr/bin/find` explicitly.
6. **Another session may be actively editing ad-removal / build-fix files concurrently.** Don't trust a `docs/archive/ad-removal/*.md` or `docs/archive/progress/*.md` status doc claiming something is "complete" — verify against the live files first (see `CLAUDE-status.md`).
7. **`LevelSelectionView.swift`'s `showGatekeeperAlert` is dead code.** The `@State` flag and its `.alert(...)` block exist, but nothing ever sets the flag `true` — the alert can never appear. The real 250/251-barrier messaging lives entirely in `LevelPreviewModal.swift` instead. Don't "fix" this alert expecting it to do anything; either wire it up deliberately or remove it.
8. ~~`LevelBuilderView.swift` had a save-navigation bug~~ — **fixed 2026-09-19**: the success-message string for a brand-new level (`"Level saved successfully!"`) didn't match what the dismiss-handler checked for (`"Saved successfully!"`), so saving a new custom level didn't auto-navigate back. The check now matches the real string; both create and edit paths navigate back correctly. See `GAMEPLAY_CONTROLS.md` §2.

---

## 4. Test Map

| File | What it covers | ~# tests | Compiles / consistent with real APIs? |
|---|---|---|---|
| `HighlightSettingsTests.swift` (root) | Cell highlight logic (same-number/same-note/potential-mode) via `getHighlightType` | 4 | **No** — calls a `SudokuGameViewModel(levelID:parentViewModel:)` initializer that doesn't exist |
| `OptimizationTests.swift` (root) | Timer lifecycle, board-parse perf, validation caching, move history, save debounce, hint cooldown | ~20 | **No** — calls `parseBoardString` (actually `private`) and `handleNumberInput` (doesn't exist; real method is `didTapNumber(_:)`) |
| `SequentialUnlockTests.swift` (root) | Sequential/milestone unlock rules (levels 1, 2, 3, 100, 251-gate, debug-unlock) | 8 | **Likely yes** — self-contained, reimplements the unlock algorithm locally rather than calling `LevelViewModel`. Updated 2026-09-19: dropped the `hasRemovedAds` parameter and its "Remove Ads unlocks all" case to match the real algorithm after IAP removal. |
| `UnlockingLogicTests.swift` (root) | `LevelViewModel` unlock, gap handling, 250-barrier, ad-unlock | 7 | **No** — wrong `levelSolved(...)` signature, and calls `unlockLevelViaAd(...)`/`isAdUnlocked` which no longer exist anywhere in `LevelViewModel`/`SudokuLevel` at all (not just a signature mismatch — the whole mechanic was removed 2026-09-19) |
| `TestHelpers.swift` (root) | Not a test file — `XCTestCase` extension: `emptyBoard()`, board flatten/unflatten, `validateMove`/`validateBoard` wrapping the real `validate(board:rules:)` | n/a | Helpers themselves are API-consistent, but not wired into the test target (see below) |
| `SudokuiOSUITests/SudokuiOSUITests.swift` (repo root) | XCUITest end-to-end: launch → main menu → level 1 → digit entry/undo → Settings. Label-driven (no accessibility identifiers). See `CLAUDE.md` "Tap through the app" | 4 | **Yes** — runs in the `SudokuiOS` scheme (added 2026-09-20) |
| `SudokuiOSTests/KnightKingLogicTests.swift` | Knight/King adjacency + tutorial highlighting | 3 | **Likely yes** |
| `SudokuiOSTests/KropkiLogicTests.swift` | White/black dot + negative-constraint validation | 3 | **Likely yes** |
| `SudokuiOSTests/LevelManagerTests.swift` | Level count (600), 251-gate, ad-unlock, next-level redirection, filters | 5 | **No** — wrong `findNextUnsolvedLevel` label/return type; also calls `unlockLevelViaAd`/`isAdUnlocked`, which no longer exist anywhere (mechanic removed 2026-09-19) |
| `SudokuiOSTests/LevelPreviewTests.swift` | Rule display names, time formatting, 251-gate | 3 | **No** — `makeLevel` helper uses a `SudokuLevel` initializer shape (`grid`/`timeElapsed` params) that doesn't match the real struct |
| `SudokuiOSTests/LevelSelectionTests.swift` | Filter logic, first-unsolved lookup, 251-lock guard | 9 | **No** — constructs `SudokuLevel` omitting required `isLocked`/`isSolved` params |
| `SudokuiOSTests/LevelViewModelTests.swift` | Init state, async level loading, `getLevel(by:)`, hybrid-rule JSON decoding | 4 | **Likely yes** |
| `SudokuiOSTests/OddEvenLogicTests.swift` | Parity constraint validation | 3 | **Likely yes** |
| `SudokuiOSTests/PersistenceTests.swift` | SwiftData persistence of `UserLevelProgress`/`AppSettings` | 3 | **No** — uses a nonexistent `id:`/`stars:` shape for `UserLevelProgress` (real init uses `levelID:`, no `stars`) |
| `SudokuiOSTests/SudokuGameViewModelTests.swift` | Dynamic title/rule display, conflict handling, legacy-rule regression | 4 | **Likely yes** |
| `SudokuiOSTests/SudokuValidatorTests.swift` | Classic row/col/box duplicates, non-consecutive adjacency | 5 | **Likely yes** |
| `SudokuiOSTests/SudokuEngineTests.swift` | Broad rule-engine validation | 664 lines | **Known broken** — nonexistent `isValidMove(...)`, wrong `Arrow`/`Cage` constructors (see `GAME_LOGIC_AND_RULES.md` §1.11) |
| `SudokuiOSTests/SudokuRulesTests.swift` | Rule-specific validation | — | **Known broken** — same class of issue as above |

**Test-target split is a real inconsistency, not intentional.** Per `project.pbxproj` (file-system-synchronized groups): everything physically under `SudokuiOS/SudokuiOSTests/` compiles into the test target automatically; everything under the main `SudokuiOS/` app folder compiles into the **app target**. Only `SequentialUnlockTests.swift` has an explicit membership override moving it to the test target. The other four root-level test files (`HighlightSettingsTests.swift`, `OptimizationTests.swift`, `UnlockingLogicTests.swift`, `TestHelpers.swift`) are wrapped in `#if canImport(XCTest)`, which is false in an app target — so they silently compile to nothing and **never actually run**. Before trusting any of these four as "passing," first move them under `SudokuiOSTests/` (or add an explicit target membership) — and fix their API mismatches, since none of the three that aren't `TestHelpers`/`SequentialUnlockTests` currently compile even standalone.

**Bottom line**: of ~16 test files, roughly 9 look API-consistent; the rest reference methods/initializers that were renamed or removed (mostly during the unlock-system and ad-removal refactors) and need fixing before they're trustworthy as either regression coverage or as copy-paste examples.
