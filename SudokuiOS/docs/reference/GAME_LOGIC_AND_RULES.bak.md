# Sudoku Game Logic & Rules — Source of Truth

This document is a reverse-engineered map of every rule, validation algorithm, and game-loop
behavior currently implemented in this app. It exists so future changes (ad-removal cleanup,
refactors, new features) can be checked against **actual shipped behavior** instead of
assumptions. Every claim below is sourced from the code (file:line) as of this scan.

**Golden rule for future work:** if you change behavior described here, update this doc in the
same commit. If you're not sure whether something is live or dead code, check the "Live vs. Dead
Code" table in §0 first — this codebase has several unused parallel implementations left over
from an in-progress refactor.

---

## 0. Live vs. Dead Code (read this first)

**UPDATE (Sept 18, 2026):** Phase 1 cleanup removed 6 confirmed dead files (~1,067 lines). See `PHASE1_CLEANUP.md` for details.

The repo previously contained a set of "manager" classes that looked like a clean extraction of
`SudokuGameViewModel`'s responsibilities, but **none of them were wired into the live game**.
`SudokuGameViewModel.swift` (2865 lines) remains the single source of truth for all gameplay.

| Component | Status | Notes |
|---|---|---|
| `SudokuGameViewModel.swift` | **LIVE** | The real game engine. All board state, move validation, win detection, mistakes, undo/redo, hints, timer, save/load live here. |
| ~~`GameStateManager.swift`~~ | **DELETED** | Removed in Phase 1 cleanup - was completely unused. |
| ~~`MoveHistoryManager.swift`~~ | **DELETED** | Removed in Phase 1 cleanup - real undo/redo is SwiftData-backed (§4.5). |
| ~~`TimerManager.swift`~~ | **DELETED** | Removed in Phase 1 cleanup - real timer logic is inline in `SudokuGameViewModel` (§4.7). |
| ~~`HintSystemManager.swift`~~ | **DELETED** | Removed in Phase 1 cleanup - real hint system (§2.3) is already ad-free in `SudokuGameViewModel`. |
| ~~`GamePersistenceManager.swift`~~ | **DELETED** | Removed in Phase 1 cleanup - real save/load is inline in `SudokuGameViewModel` (§4.8). |
| `PotentialHighlightCalculator.swift` | **LIVE** | The authoritative "valid placement" highlight algorithm (§2.2). |
| ~~`OptimizedPotentialHighlightCalculator.swift`~~ | **DELETED** | Removed in Phase 1 cleanup - was incomplete and never used. |
| `HumanLogicSolver.swift` | **LIVE, narrow scope** | Only used by the Level Builder's "is this solvable" check (§2.1), not for in-game hints/highlights. |
| `PointingPairsSolver.swift` (incl. nested `SandwichSolver`) | **Present, unclear if wired** | Duplicates constraint logic found elsewhere. No confirmed call site found — verify before relying on or modifying it. Phase 3 candidate for deletion. |

**Why this matters:** if a future task is "improve the hint system" or "speed up highlighting,"
the correct file to touch is `SudokuGameViewModel.swift` / `PotentialHighlightCalculator.swift`.

---

## 1. Rule Variants

### 1.0 Two parallel type systems

- **`SudokuRuleType`** (`SudokuRuleType.swift`) — a plain `String` enum, no associated values.
  Used for JSON decoding, UI display (name/icon/tag color), and as the `types: [SudokuRuleType]`
  array stored on `SudokuLevel`/`CustomSudokuLevel`. Cases: `classic`, `sandwich`, `arrow`,
  `thermo`, `killer`, `nonConsecutive`, `kropki`, `oddEven`, `knight`, `king`. **These are the
  only 10 variants that exist in the app** — no diagonal/renban/whispers/extra-region variants.
- **`SudokuRule`** (`SudokuValidator.swift:3-17`) — an enum **with associated constraint data**
  (cage lists, arrow paths, dot lists, etc.), built at play time from a level's raw fields, and
  fed to `SudokuValidator.validate(board:rules:) -> Bool`.

**Combining variants:** a level can have multiple variants active simultaneously
(`types: [SudokuRuleType]` + `[SudokuRule]` array). Validation is a pure **AND** — every rule in
the array must pass on the full board; the first failing rule short-circuits `false`
(`SudokuValidator.swift:21-63`). Non-Consecutive is designed as an orthogonal "modifier"
combinable with any other variant — it's parsed as a separate token and has bespoke
combination-filtering logic when paired with Killer or Sandwich (see below). Confirmed by
campaign data: levels 251-600 are hybrids like `"killer,non-consecutive"` or
`"arrow,sandwich,non-consecutive"`.

Multi-rule string parsing: `SudokuRuleType.allRules(from:)` (`SudokuRuleType.swift:30-82`) parses
a comma-separated string; unrecognized tokens fall back to `.classic` with a console warning
(does not crash).

### 1.1 Classic (`.classic`)

> "Numbers cannot repeat in the same row, column, or 3x3 box." — RulesView.swift:206

- **Validator:** `SudokuValidator.validateClassic` (`SudokuValidator.swift:143-184`). Operates on
  a **complete, fully-filled 9x9 board only** — any `0` anywhere makes it return `false`. Uses a
  `UInt16` bitmask per row/col/box; box index = `(r/3)*3 + (c/3)`.
- **Live incremental move validation** (the actual per-keystroke check during play) is a
  *different* function: `SudokuGameViewModel.isValid(_:at:ignoring:)`
  (`SudokuGameViewModel.swift:2371`). Do not confuse the two — `SudokuValidator.validateClassic`
  cannot tell you if a single move is legal mid-game.

### 1.2 Sandwich (`.sandwich(rows:, cols:)`)

> "Clues outside the grid show the sum of digits sandwiched between 1 and 9." — RulesView.swift:219

- **Validator:** `SudokuValidator.validateSandwich`/`calculateSandwichSum`
  (`SudokuValidator.swift:67-116`).
- Per row/col with a non-nil clue: locate index of `1` and `9`. **If either is missing, the clue
  is silently skipped** (not a failure) — this is the ONLY variant that tolerates incompleteness
  this way.
- If `1` and `9` are adjacent (`maxIdx - minIdx <= 1`), sum = `0`.
- Otherwise sum = sum of all cells strictly between them, **including zeros from empty cells** —
  i.e. it does NOT wait for full completion once both crusts exist; a wrong partial sum fails
  immediately.
- Sum must exactly equal the clue.
- Builder input constraint: clue value must be `0` or in `2...35` (UI-level, `LevelBuilderViewModel.swift`).
- `SandwichMath.swift` provides combination generation (digits from `{2..8}` summing to target)
  for the in-game "helper" UI and level builder — **not used for live validation**.
  `SandwichMath.isValidUnderNonConsecutive` filters those combinations against the
  non-consecutive modifier when both are active on a level.
- "Cross" tool (UI aid only): marks cells that definitely cannot be 1 or 9.

### 1.3 Thermo (`.thermo(paths:)`)

> "Numbers must strictly increase from the bulb to the tip." — RulesView.swift:212

- **Validator:** `SudokuValidator.validateThermo` (`SudokuValidator.swift:381-410`).
- Iterates each path in order (bulb first). Out-of-bounds coords are skipped. **First empty cell
  on a path stops checking that path** (partial thermos are tolerated).
- Strictly increasing required: `val <= currentVal` (equal values fail too). Gaps between values
  are fine — no requirement of consecutiveness, just strict ascending order.

### 1.4 Arrow (`.arrow([Arrow])`)

> "Numbers along the arrow must sum to the number in the circle." — RulesView.swift:211

- **Data model:** `SudokuLevel.Arrow { bulb: [Int]; line: [[Int]] }` — field names are `bulb`
  and `line` (singular), not `circle`/`lines`.
- **Validator:** `SudokuValidator.validateArrow` (`SudokuValidator.swift:186-207`).
- Bulb must be exactly 2 coords, else that arrow is skipped.
- **Unlike Sandwich, an empty bulb or any empty line cell makes validation hard-fail
  (`return false`)** — arrows are not tolerant of incompleteness.
- Sum of line cells must equal bulb value exactly.
- Single-cell arrows (line length 1, direct value copy) are supported.

### 1.5 Killer (`.killer([Cage])`)

> "Numbers in cages must sum to the corner clue and cannot repeat." — RulesView.swift:210

- **Data model:** `SudokuLevel.Cage { sum: Int; cells: [[Int]] }` (computed `topLeft`). The type
  is `Cage`, not `KillerCage`.
- **Validator:** `SudokuValidator.validateKiller` (`SudokuValidator.swift:209-236`).
- **Any empty cell in a cage hard-fails validation** (same as Arrow, unlike Sandwich).
- Two independent checks: (1) sum of cage cells == `cage.sum`; (2) no duplicate values within
  the cage (independent of row/col/box uniqueness).
- `KillerMath.swift` provides combination generation for the helper UI/level builder (not live
  validation): `getCombinations(sum:count:rules:cageCells:)` enumerates ascending digit subsets
  of `1...9`, filtered by `isValidUnderNonConsecutive` when the modifier is active (checks
  whether *some* assignment of the combo to orthogonally-adjacent cage cells avoids consecutive
  neighbors — an existence check, not a full per-board enforcement).

### 1.6 Kropki (`.kropki(white:, black:, negativeConstraint:)`)

> White dot: difference is 1. Black dot: ratio is 2:1. (1 & 2 satisfy both, so either dot works for that pair.) — RulesView.swift:217

- **Data model:** `SudokuLevel.KropkiDot { r1,c1,r2,c2 }`, decodable from either a keyed object
  or a 4-element array.
- **Validator:** `SudokuValidator.validateKropki` (`SudokuValidator.swift:238-305`).
- White dot: `abs(v1-v2) == 1`, either endpoint `0` → fail.
- Black dot: `v1 == 2*v2 || v2 == 2*v1`, either endpoint `0` → fail.
- **Negative constraint** (optional, per level): if enabled, EVERY orthogonally-adjacent pair in
  the whole grid that does NOT have an explicit dot must **not** satisfy either relation (both
  cells filled, `abs(diff)==1` → fail; ratio 2:1 → fail). Dot-existence check is exact coordinate
  match, order-agnostic.
- **Known duplicate implementation risk:** `PointingPairsSolver.swift:108-162` reimplements this
  exact same white/black/negative math independently for the hint/highlight system. Currently
  consistent with `SudokuValidator`, but any future change to Kropki rules must be applied in
  both places or they will silently diverge.
- Rendering only, no logic: `KropkiLayer.swift`, `KropkiBorder.swift`.

### 1.7 Odd-Even (`.oddEven(parity:)`)

> Square-framed cells are Even. Circle-framed cells are Odd. — RulesView.swift:218

- **Data format:** 81-char string, index = `row*9+col`. `'0'`=unconstrained, `'1'`=must be odd,
  `'2'`=must be even.
- **Validator:** `SudokuValidator.validateOddEven` (`SudokuValidator.swift:307-327`).
- **Fails open on malformed input**: if the parity string isn't exactly 81 chars, the whole rule
  is silently treated as always-valid (not a crash, not a failure — just ignored). Be aware of
  this if debugging an odd-even level that seems to accept invalid boards.
- Rendering only, no logic: `OddEvenLayer.swift`.

### 1.8 Knight's Move (`.knight`)

> "Same numbers cannot be a Knight's move apart." — RulesView.swift:208

- **Validator:** `SudokuValidator.validateKnight` (`SudokuValidator.swift:329-353`). Checks all 8
  standard L-shape offsets: `(±2,±1)` and `(±1,±2)`.
- **Duplicate offset arrays exist in 3 places**: `HighlightManager.knightOffsets`,
  `PotentialHighlightCalculator.swift:183-184` (inline literal), and the validator itself. Keep
  in sync if ever changed.

### 1.9 King's Move (`.king`)

> "Same numbers cannot be in any adjacent cell, including diagonals." — RulesView.swift:209

- **Validator:** `SudokuValidator.validateKing` (`SudokuValidator.swift:355-379`). Checks the
  full 8-cell Moore neighborhood (orthogonal **and** diagonal), despite the "King's move" name
  suggesting diagonal-only. (The in-app `HowToPlayView.swift:116` copy undersells this by saying
  "diagonally touching cells" — the RulesView.swift:209 copy is the accurate one. Orthogonal
  adjacency here is functionally redundant with Classic row/col rules, but the check still runs
  independently.)

### 1.10 Non-Consecutive (`.nonConsecutive`, a composable modifier)

> "Adjacent cells cannot contain consecutive numbers." — RulesView.swift:207

- **Validator:** `SudokuValidator.validateNonConsecutive` (`SudokuValidator.swift:118-141`).
  Orthogonal neighbors only (right + down sweep covers all pairs once). `abs(diff) == 1` between
  filled orthogonal neighbors → fail. Empty cells skipped.
- Combines with Killer/Sandwich via their own bespoke combination-filtering logic (see §1.2,
  §1.5) since cage/sandwich cells aren't necessarily in a line.
- Also affects **note auto-pruning** during play (§4.4) and **`HumanLogicSolver`**'s solving
  strategy (§4.1) beyond just board validation.

### 1.11 Known test/code inconsistencies (do not treat these test files as passing/authoritative)

- `SudokuEngineTests.swift` and `SudokuRulesTests.swift` call `validator.isValidMove(...)`, which
  **does not exist anywhere in the codebase** — these test files will not currently compile.
- `SudokuEngineTests.swift` constructs `SudokuLevel.Arrow(circle:lines:)` and
  `SudokuLevel.KillerCage(sum:cells:)` — neither matches the real struct names/field names
  (`Arrow(bulb:line:)`, `SudokuLevel.Cage`). Will not compile.
- Test cases for "incomplete Arrow" and "incomplete Killer cage" assert `true` (should pass), but
  the actual validator code (`if val == 0 { return false }`) would return `false` for those same
  inputs — a real contradiction between stated intent and shipped behavior, currently latent only
  because the tests don't compile. **If you fix these tests, first decide/confirm which behavior
  is correct (fail-on-incomplete, matching current code) before "fixing" the assertions.**

---

## 2. Solver & Hint/Highlight Logic

### 2.1 `HumanLogicSolver` — level-builder validation only, NOT live hints

Constraint-propagation solver, used exclusively by `LevelBuilderViewModel.checkValidation()`
(`LevelBuilderViewModel.swift:553`) to give the level-builder UI an advisory "Human-Solvable"
message. **Does not run during normal gameplay.**

**Reference in §0 table:** Listed as "LIVE, narrow scope"

- `solve(maxIterations: Int = 100)` runs a fixed-point loop, re-trying classic rules first after
  any change, then variant rules in this priority order per pass: classic → non-consecutive
  implications → knight → king → thermo → arrow → killer → kropki → sandwich → odd-even. Stops
  when a full pass makes no change or after 100 iterations.
- Classic techniques implemented (all in `applyClassicRules`): Naked Singles, Hidden Singles,
  Naked Pairs, Pointing Pairs/Box-Line Reduction, Naked Triples, Hidden Pairs.
- Variant-specific solving logic exists for every one of the 10 rule types (see the source for
  exact algorithms if extending this).
- **"Valid" only means the human-technique solver fully resolves the board without stalling** —
  it does NOT prove the solution is unique. The builder UI's own footnote admits this
  ("Automated verification can make mistakes or might not cover all logical paths a human can").
- **Sandwich solving is explicitly weaker than the rest**: comments in the code
  (`HumanLogicSolver.swift:909-912`) note it does an approximate feasibility check rather than a
  full existence proof, unlike the other variants.
- Kropki negative-constraint solving note: a "negative constraint" flag exists in a Python
  reference implementation the Swift code was ported from, but is **not implemented** here — only
  explicit dots are enforced during solving (though it IS enforced during actual board
  *validation*, §1.6 — this gap is solver-only).

### 2.2 `PotentialHighlightCalculator` — LIVE, the real "valid placement" highlighter

`static func calculatePotentials(board:digit:rules:isValid:) -> Set<Int>` returns **restricted**
cell indices (cells that should NOT be shown as valid placements), consumed by
`SudokuGameViewModel.updateRestrictions()`/`updatePointPairRestrictions()`
(`SudokuGameViewModel.swift:721,797,845,872,1179` and `797,845,1010,1020`), only active when
`settings.highlightMode == .potential`.

**Reference in §0 table:** Listed as "LIVE" - the authoritative implementation.

Algorithm:
1. Base potentials = every empty cell where `isValid(digit, cell)` is true.
2. Up to 10 pruning passes, stopping early if a pass makes no change:
   - Pointing (box→line): if all in-box candidates for a digit share a row/col, remove that
     row/col's candidates outside the box.
   - Box/Line Reduction (line→box): inverse direction.
   - Generic Pointing Elimination: computes the intersection of "attacked cells" (row/col/box
     peers, plus knight/king peers if those variants are active) across all candidate cells in a
     house; a nonempty common-attacked set gets pruned. This is what generalizes pointing/claiming
     to Knight/King variant geometries.
3. Empty Box Contradiction Check (once, after the loop): excludes a candidate if placing it would
   leave some other digit-less box with zero remaining valid cells.
4. No caching/memoization anywhere in this file — every call rescans up to O(81) per house.

**Known gap:** there is no unit test asserting exact expected output for this calculator — any
future refactor here has no regression-test safety net today.

### 2.3 Live Hint System (inline in `SudokuGameViewModel`, NOT `HintSystemManager.swift`)

**Note:** `HintSystemManager.swift` was deleted in Phase 1 cleanup (Sept 18, 2026) - it was never wired in and had stale ad-callback logic.

- `useHint()` (`SudokuGameViewModel.swift:1721`), guarded by `!isGameOver && !isSolved`.
- Two modes via `settings.hintTarget`:
  - `.selectedCell` (default): requires exactly one selected, non-clue, currently-incorrect cell,
    else shows an error alert with a specific message ("select an empty cell" / "already correct"
    / "cannot use a hint on a given clue").
  - Otherwise (random mode): picks a random non-clue cell that's empty or wrong.
- Places the correct digit via the normal `enterNumber` path (so it's undo-able and goes through
  the same batch/history machinery); correct-value placement never counts as a mistake.
- Increments `hintsUsed` (used later to compute the "perfect" flag: `mistakesCount == 0 &&
  hintsUsed == 0`).
- **Cooldown: hard-coded 5 minutes (300s)**, stored as a `Date` in
  `UserDefaults["nextHintAvailableDate"]`, ticked down once/second in the view model for display.
  **No ad or IAP gating exists in this path at all** — hints are already fully ad-free apart from
  the flat cooldown. (Relevant to the ad-removal task in the main CLAUDE.md: this part is already
  done, despite that doc describing hints as ad-gated — that description is stale.)
- **No per-level hint limit** beyond the cooldown; a player can use unlimited hints, 5 minutes
  apart, until the puzzle is solved or game-over.
- The cooldown *display* is view-model state; the actual disable-the-button gating happens in
  `SudokuGameView.swift:611-632` reading `hintCooldownRemaining` — `useHint()` itself has no
  internal cooldown guard (relies on the UI not calling it).

---

## 3. Level Progression, Unlocking & Custom Levels

### 3.1 Campaign structure

- Source: bundled `Levels.json`, **600 total levels**.
- **Section 1 (ids 1-250):** fixed repeating 10-level cycle by `id % 10`:
  `1`→classic, `2`→non-consecutive, `3`→sandwich, `4`→thermo, `5`→arrow, `6`→killer, `7`→kropki,
  `8`→odd-even, `9`→knight, `0`→king. Difficulty escalates in 50-level bands: 1-50 "Super Easy",
  51-100 "Easy", 101-150 "Medium", 151-200 "Hard", 201-250 "Extreme" (Sandwich levels are always
  tagged "Variant" regardless of band).
- **Section 2 (ids 251-600, 350 levels):** hybrid puzzles, always including `non-consecutive` plus
  1-2 heavy variants. Difficulty bands: 251-330 "Light Hard", 331-430 "Very Hard", 431-530
  "Extreme", 531-600 "Insane".
- Difficulty labels are **static data baked into the JSON**, not computed at runtime by any
  solver/rating algorithm.

### 3.2 Sequential unlock algorithm — `LevelViewModel.recalculateLocks` (`LevelViewModel.swift:739-789`)

Exact rule order, evaluated per level:
1. Debug override (`debugUnlock`) → unlocks everything.
2. Already solved → always unlocked (sticky).
3. Level 1 → always unlocked.
4. "Remove Ads" IAP (`hasRemovedAds`, reads `UserDefaults["isAdsRemoved"]`) → unlocks everything.
5. **Sequential rule**: unlocked if the array-previous level (`levels[i-1]`, i.e. id N-1) is
   solved — **AND**, if `levelID > 250`, ALL of levels 1-250 must also be solved (the
   Section-1/Section-2 barrier). Solving level 250 alone is not enough to open 251 if any earlier
   level in 1-250 is still unsolved.
6. Otherwise locked.

Important nuances confirmed by tests:
- **Ad-unlock is not durable across an unrelated `refreshLocks()` call.** `unlockLevelViaAd()`
  directly flips `isLocked=false` as a side effect, but `recalculateLocks` never reads
  `isAdUnlocked` — so a later unrelated `refreshLocks()` (e.g. from solving a different level) can
  re-lock an ad-unlocked-but-gapped level unless it was also solved. Confirmed by
  `UnlockingLogicTests.testGapHandling`.
- The persisted "sticky" `isUnlocked` flag is tracked and stored but **currently not consulted at
  all** by `recalculateLocks` — vestigial with respect to the lock computation. Flag this to
  anyone extending the unlock system; don't assume setting `isUnlocked=true` alone unlocks
  anything.
- `UnlockingLogicTests.testRemoveAdsUnlock` writes to UserDefaults key `"isAdFree"`, but the real
  getter (`hasRemovedAds`) reads `"isAdsRemoved"` — likely a stale/broken test, don't trust it as
  a live regression check for that flag.
- `LevelViewModel.isMilestoneOneComplete` uses the identical `firstSectionSolved` predicate
  (all of 1-250 solved) as the barrier check.

### 3.3 Progress tracking

Per-level state lives in SwiftData `UserLevelProgress` (unique on `levelID`): `isSolved`,
`bestTime` (lowest ever), `lastSolvedTime` (most recent), `isPerfect` (sticky — once achieved,
never unset), `mistakesMade` (overwritten each run, not cumulative), plus board/notes/colors/
marks/cross snapshot data and a `moves: [MoveHistory]` relationship (cascade delete).

- `resetLevelProgress` explicitly **preserves `bestTime`/`lastSolvedTime`** so restarting a level
  doesn't erase personal records.
- `levelSolved(...)` is the completion orchestration entry point: marks solved → saves progress →
  `unlockLevel(id + 1)` → `refreshLocks()`.
- Key UserDefaults: `"com.sudokuios.unlockedLevels"` (sticky unlock list, redundant with the
  SwiftData flag), `"isAdsRemoved"` (IAP flag — **this is the real key**), `"devAllUnlocked"`
  (debug override), plus session-resume keys (`"active_standard_session"`,
  `"active_custom_session"`, `"lastPlayedMode"`, `"lastCustomLevelUUID"`, etc.).

### 3.4 Custom Level Builder — no hard validation gate on save

- `saveLevel`/`commitSave` do **not** require validation to pass — a user can save an
  empty/unsolvable board with no error.
- No minimum-clue-count enforcement anywhere.
- No brute-force unique-solution check. The only check is the advisory `HumanLogicSolver`-based
  "Human-Solvable" message described in §2.1 — informational only, not a save gate.
- Live UI-level input constraints while editing (not save-time validation): max 9 placements of
  the same clue digit; Thermo/Arrow paths built by sequential king-adjacent taps (Thermo max
  length 5 if non-consecutive active else 9; Arrow max length 10; Cage max length 9); Killer cage
  cells must be orthogonally adjacent to *any* existing cage cell; Kropki dots placed via two
  orthogonally-adjacent taps; sandwich clue input range `0` or `2...35`; cage sum input range
  `1...45`.
- Rule-toggle exclusivity: Classic and Non-Consecutive are mutually exclusive (picking one clears
  the other; at least one must remain active). King/Knight are independent additive toggles.
- Primary `ruleType` (single value, for legacy display) is derived by priority King > Knight >
  Sandwich(if clues present) > Classic — this priority list does NOT consider
  thermo/arrow/killer/kropki/odd-even/non-consecutive when picking the single display value,
  though all variant data is still stored and reconstituted into the full `types` array.

### 3.5 Custom level persistence differences vs. campaign levels

- `CustomSudokuLevel` (SwiftData `@Model`) self-hosts its own progress fields
  (`savedBoardProgress`, `savedNotesData`, etc., plus `savedTime`) — custom levels do **not** use
  `UserLevelProgress` at all.
- Never lock-gated (`isLocked` always `false` when converted via `toSudokuLevel()`).
- `solution` is optional and, per the builder, **never populated** — custom-level win detection
  therefore cannot use a stored-solution string comparison (see §4.3, custom levels validate
  mathematically instead).
- Synthetic negative `id` derived from `UUID.hashValue % 1000` — only 1000 distinct buckets, a
  theoretical (low-probability) collision risk between two custom levels' ids.

---

## 4. Core Game Loop (`SudokuGameViewModel.swift`)

### 4.1 Board state representation

- `@Observable class SudokuCellModel` — the real runtime source of truth (`id`, `value`,
  `notes: Set<Int>`, `color`, `hasCross`, `isClue`, `parity`). `@Published var cells:
  [SudokuCellModel]`, 81 elements, index = `row*9+col`.
- `currentBoard`/`currentBoardArray` are **derived mirrors** rebuilt from `cells`, not
  independently authoritative.
- `initialBoard`/`initialBoardArray` = the clues, parsed once. `isClue(at:)` checks against this.
- `solution`/`solutionArray` = full solved board — **populated for standard levels only**; empty
  for custom levels (`isCustomLevel: Bool { levelID < 0 }`).

### 4.2 Move validation flow — `enterNumber` → `applyNumberBatch`

Order of operations per selected cell (clues are skipped):
1. Toggle: same value tapped again → clears to `0`; otherwise sets the new value.
2. No-op skip if nothing actually changes.
3. Clear that cell's notes (recorded as a `"Note"` history move).
4. Clear `hasCross` (⚠ NOT recorded in move history — a known gap; undoing a value placement will
   not restore a cleared cross mark).
5. Write the value; record a `"Value"` history move **before** the mistake check.
6. **Mistake check** — exact condition:
   ```swift
   if !isCustomLevel {
       let isLimitEnabled = settings?.isMistakeLimitEnabled ?? true
       if targetValue != 0 && isLimitEnabled {
           let isIncorrect = targetValue != solutionArray[index]
           if isIncorrect {
               mistakesCount += 1
               if mistakesCount >= 3 { isGameOver = true; stopTimer() }
               // wrong value is still placed, NOT reverted
           }
       }
   }
   ```
   Custom levels never count mistakes (no solution array to check against). Clearing a cell never
   counts as a mistake regardless of level type.
7. If a non-zero value was placed: auto-prune notes (§4.4).
8. After the whole selection loop: `finishBatchUpdate()` → `applyCombinationAutoFilter()` →
   `finishBatchUpdate(checkWin: true, wasBoardFull: <captured before this call's edits>)`.

Multi-select (`selectedIndices.count > 1`) or note-mode-on always routes to `toggleNote` instead
of value entry, regardless of the note-mode toggle state.

### 4.3 Win/completion detection — `checkForWin(wasBoardFull:)`

- No-op unless `cells.allSatisfy { $0.value != 0 }` (board must be completely full).
- **Custom levels** (no stored solution): validated mathematically via
  `SudokuValidator().validate(board:rules:)` against the level's active rule set.
- **Standard levels**: exact string comparison, `cells.map{String($0.value)}.joined() ==
  solution`.
- A full-but-wrong board on its *first* transition to full still triggers the victory-wave visual
  sweep (used to reveal mistakes, not to declare a win) — actual completion is re-verified
  afterward in `finalizeVictoryCheck()`.
- `completeGame()`: stops timer, `isSolved = true`, updates `bestTime` if improved, computes
  `isPerfect = (mistakesCount == 0 && hintsUsed == 0)`, calls
  `parentViewModel.levelSolved(...)`, clears all session-resume UserDefaults keys, saves state,
  then (after a 0.5s delay) sets `isGameComplete = true` to drive the victory overlay.

### 4.4 Notes / pencil marks & auto-clear

- `toggleNote`: batch-consistent toggle — if *any* selected empty cell is missing the note, it's
  added to all selected empty cells; otherwise removed from all (not per-cell independent).
- **Auto-prune on placement** (`autoPruneNotes`, always runs when a non-zero value is placed):
  - Removes the placed value from notes of every other empty cell in the same row/col/box.
  - **If Non-Consecutive is active**, ALSO removes `value-1` and `value+1` from the 4 orthogonal
    neighbor cells' notes.
  - Each removal is recorded as its own history entry sharing the placement's `batchID`, so
    undoing the placement restores the pruned notes too.
- "Corner 1/9" shortcut (`didTap19`): adds/removes notes for 1 and 9 across selected empty cells
  based on live placement-validity, same batch add/remove-all semantics as `toggleNote`.

### 4.5 Undo / Redo — real implementation is SwiftData-backed, not `MoveHistoryManager`

**Note:** `MoveHistoryManager.swift` was deleted in Phase 1 cleanup (Sept 18, 2026) - it was never wired in and had a 100-move cap that the real system doesn't have.

- History = `MoveHistory` (`@Model`) records under `UserLevelProgress.moves`
  (cascade-delete relationship). Fields: `orderIndex`, `cellIndex`, `moveType`
  (`"Value"`/`"Note"`/`"Color"`/`"Cross"`), `oldValue`/`newValue`, `batchID`.
- `historyIndex` is an in-memory cursor, rebuilt on load as `moves.count - 1`.
- `addMove(...)`: common case just appends. If the user undid and then made a new move (branching
  history), **all moves after `historyIndex` are permanently deleted** (both from `modelContext`
  and the in-memory array) before the new move is appended — redo history is discarded on branch,
  not preserved as a tree.
- `undo()`/`redo()` apply/restore `oldValue`/`newValue` via `applyChange`, and **walk backward/
  forward through consecutive moves sharing the same `batchID`** so a whole multi-cell action
  (e.g. clear-notes-then-set-value, paint colors across a selection, a hint) undoes/redoes
  atomically in one user gesture.
- No cap on history size in the live implementation (the 100-move cap only exists in the unused
  `MoveHistoryManager`).

### 4.6 Mistakes — display vs. counting are two separate mechanisms

- **Counting** (drives game-over): described in §4.2 step 6. Hard limit **3 mistakes**. Gated
  entirely by `settings.isMistakeLimitEnabled` (default `true`) — if disabled, mistakes are never
  counted at all, not just never game-over'd.
- **Display** (`isMistake(at:)`): independent of the counter. True if solution mismatch
  (standard levels only) OR a Non-Consecutive violation (`hasConsecutiveNeighbor`, applies to all
  levels including custom, since it's a rule check not a solution check).
- **Visibility gating** (`shouldShowMistake`, per `settings.mistakeMode`):
  - `.never` — never show red highlight.
  - `.immediate` — show as soon as it's wrong.
  - `.onFull` (default) — only reveal after the board is full, via the victory-wave sweep
    (`revealedMistakeIndices`), not immediately on entry.
- There is **no "check board" / mistake-replay feature** anywhere — mistake revelation only
  happens through the full-board victory-wave sweep.

### 4.7 Timer

**Note:** `TimerManager.swift` was deleted in Phase 1 cleanup (Sept 18, 2026) - it was never wired in. Real timer logic is inline here.

- `shouldRunTimer`: `!isPaused && !isSettingsPresented && !isRulesPresented && !isGameComplete`
  (note: does not check `isSolved` directly, only indirectly via `isGameComplete` which lags
  `isSolved` by ~0.5s).
- 1-second repeating `Timer`; pauses/resumes are driven by an explicit pause button, the
  settings/rules sheets being presented, and app scene-phase changes (`.active` → start,
  `.background`/`.inactive` → stop).
- `stopTimer()` calls the **debounced** `saveState()` (2s delay), not the immediate variant — a
  theoretical data-loss window exists if the app is force-killed within that 2s window right
  after backgrounding. Worth knowing if investigating "lost progress" reports.

### 4.8 Save / load — two channels, both inline (not via `GamePersistenceManager`)

**Note:** `GamePersistenceManager.swift` was deleted in Phase 1 cleanup (Sept 18, 2026) - it was never wired in. Real persistence is inline here.

**Channel A — SwiftData `UserLevelProgress` (durable, authoritative):**
- `saveState()` is debounced 2.0s; `saveStateImmediate()` bypasses the debounce for critical
  moments.
- `performSaveState()` rebuilds board/notes/colors/crosses/marked-combinations from `cells`,
  upserts the `UserLevelProgress` row (and mirrors onto `CustomSudokuLevel.saved*` fields if it's
  a custom level), then `context.save()`.

**Channel B — `GameSession` (Codable, UserDefaults, lightweight "Continue" pointer):**
- `saveGameSession()` early-returns if the game is solved/complete (no ghost sessions).
- For standard levels: full session JSON goes into
  `UserDefaults["active_standard_session"]`.
- For custom levels: the heavy board data is NOT duplicated here (it already lives on
  `CustomSudokuLevel` via Channel A) — only an in-memory `activeSession` pointer is kept, and the
  UserDefaults key is explicitly removed.
- All session keys are cleared on `completeGame()`.

**Load priority on `setupLevel`:** an explicitly-passed `session` > SwiftData
`UserLevelProgress`/`CustomSudokuLevel` saved fields > fresh initial board. Each of
board/notes/colors/marks/cross-data is resolved independently with this same fallback chain.
**Gameplay stats (`mistakesCount`, `hintsUsed`, `isGameOver`, hint cooldown timer) are always
reset to 0/false on load — they do NOT persist across app relaunches**, only board/notes/time
survive.

`initializeCells()` has a self-healing check: if a loaded cell is marked as a clue but its value
doesn't match `initialBoardArray`, it force-corrects to the clue value and schedules an async save
— a guard against corrupted/stale saved state.

**Custom levels reuse the exact same engine**: `CustomGameWrapperView` converts a
`CustomSudokuLevel` into a transient `SudokuLevel` (`toSudokuLevel()`) and copies its `saved*`
fields onto it before handing off to the normal `SudokuGameView`/`SudokuGameViewModel` — there is
no separate game-logic path for custom levels.

### 4.9 Constants reference table

| Constant | Value | Notes |
|---|---|---|
| Max mistakes before game-over | 3 | Only when mistake limit enabled |
| Hint cooldown | 300s (5 min) | Hard-coded, no ad/IAP gating |
| Debounced save interval | 2.0s | |
| Game timer tick | 1.0s | |
| Victory wave (initial) | step 0.5, max radius 15.0, interval 0.05s | |
| Victory wave (post-handoff) | +1.5/tick, capped at 20 | Driven by the 1s game timer once running |
| Win-confirm dispatch delay | 100ms | After `finishBatchUpdate(checkWin: true)` |
| `isGameComplete` delay after `isSolved` | 500ms | Drives victory overlay timing |
| Board size | 81 cells (9x9) | |
| Board-string parse cache | 10 entries, then cleared | Perf cache, not correctness-relevant |
| Campaign sections | 1-250 (Section 1), 251-600 (Section 2, requires all of Section 1 solved) | |
| Highlight pruning passes | up to 10, early-exit on no change | `PotentialHighlightCalculator` |
| `HumanLogicSolver` max iterations | 100 | Level-builder validation only |

---

## 5. Open Risks / Things To Verify Before Relying On Them

- `SudokuEngineTests.swift` and `SudokuRulesTests.swift` currently **do not compile** against the
  live `SudokuValidator`/`SudokuLevel` APIs (calls to a nonexistent `isValidMove`, wrong
  Arrow/Cage constructor names — see §1.11). Treat their *intent* as documentation, not as a
  passing regression suite, until fixed. **Phase 2 cleanup candidate.**
- Three separate hand-maintained copies of Knight/King offset arrays; two separate hand-maintained
  copies of Kropki white/black/negative math (`SudokuValidator` and `PointingPairsSolver`); at
  least three separate copies of "classic row/col/box legality" logic
  (`SudokuValidator.validateClassic`, `PointingPairsSolver.isValidCandidate`, and
  `SudokuGameViewModel.isValid(_:at:ignoring:)`). Any rule change must be hunted down in all
  copies.
- `PointingPairsSolver.swift`'s call sites were not conclusively confirmed as wired into the live
  UI in this scan — verify before assuming it drives any visible behavior, and before modifying it
  expecting a visible effect. **Phase 3 cleanup candidate.**
- **Phase 1 cleanup complete (Sept 18, 2026):** Deleted 6 dead manager files
  (`GameStateManager`, `TimerManager`, `HintSystemManager`, `GamePersistenceManager`,
  `MoveHistoryManager`, `OptimizedPotentialHighlightCalculator`) - ~1,067 lines of confusing
  unused code removed. See `PHASE1_CLEANUP.md` for full details.
