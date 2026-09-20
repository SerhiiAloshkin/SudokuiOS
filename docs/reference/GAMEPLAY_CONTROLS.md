# Gameplay Controls Reference

Exhaustive button-by-button behavior across the app: the main game screen, the Level Builder,
and navigation/Settings. This is the technical reference — for *why* a rule works the way it
does, see `GAME_LOGIC_AND_RULES.md`; for *where* code lives, see `CODE_MAP.md`. This doc exists
so a "the X button does Y, right?" question can be answered by reading, not by re-scanning the
UI code.

**Golden rule:** if you change a button's behavior, update this doc (and the in-app Encyclopedia/
Rules text, if it describes that control) in the same commit.

---

## 1. Main Game Screen (`SudokuGameView.swift`)

### Top toolbar
| Control | Does | Enabled when | Notes |
|---|---|---|---|
| Back (chevron, top-left) | Saves state (if not solved/complete), then dismisses | always | |
| Rules "?" (top-left) | Opens `RulesView` as a sheet — nav-titled **"How to Play"** (not the same screen as the Encyclopedia, despite the name) | always | Now has a "Full Guide" button (top-left of that sheet) opening the full Encyclopedia (`HowToPlayView`) |
| Timer (center) | Display only | — | |
| Pause (top-right) | Shows the pause overlay | always | |
| Settings (top-right) | Opens `SettingsView` as a sheet | always | |

### `SudokuHeaderView`
| Control | Does | Enabled when | Notes |
|---|---|---|---|
| Hint button | See "Hint button" below | `settings.showHintButton && !isCustomLevel` | Hint is **always hidden on custom levels** regardless of the Settings toggle (no solution data to hint from) |
| Level title / rule badges | Display only | — | `RulesListView` renders active-rule icons |
| Killer helper button | Opens the Killer combination-helper overlay | Only rendered if the level has cages *and* `settings.isCombinationHelperEnabled`; **disabled until a cage cell is selected** (`selectedCage != nil`) | Easy to miss — requires tapping a cage cell first, with no visual hint that doing so unlocks the button |

### Hint button (`HintButtonView`)
- Cooldown state (`hintCooldownRemaining > 0`): shows an orange `MM:SS` countdown, disabled.
- Ready state: lightbulb icon, tap calls `useHint()` (double-guarded: both the `.disabled()` modifier and an internal cooldown check).
- Error cases (wrong number of cells selected, cell already correct, cell is a clue) surface via a separate alert (`showHintErrorAlert`), not inline.
- Cooldown is a flat 5 minutes, persisted across app restarts (see `GAME_LOGIC_AND_RULES.md` §2.3) — no per-level hint limit beyond it.

### Board interaction (`SudokuBoardView`)
- **There is no separate tap-vs-drag code path.** A single `DragGesture(minimumDistance: 0)` handles everything — a tap is just a zero-distance drag. `gestureStart(at:)` fires once, then `dragToggle(index)` fires once per cell (deduped per gesture via `processedDragIndices`); a real drag across cells calls `dragToggle` again for each newly-entered cell.
- **Multi-select mode ON**: taps/drags are additive — cells get added to the selection, never removed by tapping them again mid-gesture.
- **Multi-select mode OFF**: dragging across cells is a "pseudo-multi" selection (same additive mechanism, just without the persistent mode toggle) — see `GAME_LOGIC_AND_RULES.md`/the multi-select highlighting note below for what selecting 2+ cells changes about highlighting.
- Sandwich row/column clue labels (drawn outside the grid) are individually tappable → opens the Sandwich combination-helper overlay for that line.

### Controls toolbar (`SudokuControlsView`)
| Control | Does | Enabled when | Notes |
|---|---|---|---|
| Multi (square.on.square) | Toggles multi-select mode | always | **Long-press (0.5s)** → selects all remaining empty cells instantly |
| Undo | Reverts the last action (batched atomically per user gesture) | `canUndo` | |
| Redo | Re-applies the last undone action | `canRedo` | |
| Notes/Enter (pencil) | Toggles note-entry mode; label text itself changes between "Notes" and "Enter" | always | |
| Cross (×) | Toggles the Sandwich "cross" mark on selected cell(s) | Only shown if the level is a Sandwich variant | **Long-press (0.5s)** → crosses all remaining empty cells |
| Color (palette) | Opens a popover: tap a swatch to color selected cell(s), tap the circle-slash swatch to clear color | always | |
| Erase | Clears value + notes + color from selected cell(s) | always | |

### Number pad (`NumberPadView`)
- Digits 1-9: tap enters the digit (value mode) or toggles it as a note (note mode, or automatically when 2+ cells are selected).
- A digit is **disabled and dimmed (30% opacity)** once it's been placed 9 times on the board, but only if Settings' "Disable Completed Digits" is on.
- **"19" button**: only rendered on Sandwich levels. Tap adds/removes notes "1" and "9" across selected empty cells based on live placement-validity for each (see `GAME_LOGIC_AND_RULES.md` §4.4).

### Pause overlay (`SudokuPauseOverlayView`)
| Button | Does |
|---|---|
| Continue | Resumes (unpauses) |
| Reset Level | Shows a confirmation alert ("This will clear all your progress.") → on confirm, restarts the level and unpauses |
| Close Level | Saves state (if not solved/complete), then dismisses back to the previous screen |

### Sandwich / Killer combination-helper overlays
- **Sandwich helper**: opens when you tap a row/column clue label. Tapping a listed combination toggles it (`toggleCombination`); dismiss via its own close control.
- **Killer helper**: opens via the header's Killer helper button (requires a cage cell already selected). Same toggle/dismiss pattern (`toggleKillerCombination`).
- Both are gated by Settings' "Show Combination Helpers"; "Auto-Filter Combinations" (separate toggle) additionally auto-removes candidates that become mathematically impossible.

### Victory / Game-over overlays
- **Victory** (`VictoryOverlayView`): "Next Level" button — target level ID comes from `getNextLevelInfo()`, which redirects to the first unsolved gap if you're at the 250/251 section barrier. Label reads "Back to Level N" in the gap-filling case.
- **Game-over** (`GameOverOverlayView`, 3-mistake limit, non-custom levels only): "Restart Level" and "Back to Grid" buttons.

### ⚠️ Highlighting with multiple cells selected
With 0 or 1 cells selected, Potential-mode highlighting shows "where can this number go." **The moment a second cell is selected, highlighting silently switches to Restriction-style geometric intersection** ("which cells share a row/column/box with *every* selected cell") regardless of the Highlight Mode setting — this is a deliberate scope limit in `getHighlightType` (`mode == .potential && selectedIndices.count <= 1`), not a bug. Useful for finding cells where a candidate shared by your selected cells can be safely eliminated; confusing if you don't know it's happening. As of 2026-09-19 this is explained in-app via a one-time tip (`AppSettings.hasSeenMultiSelectHighlightNote`) and in the Encyclopedia's "Game Screen & Controls" section. Full mechanics: `GAME_LOGIC_AND_RULES.md` — search for `getHighlightType`.

---

## 2. Level Builder (`LevelBuilderView.swift` / `LevelBuilderViewModel.swift`)

### Header
| Control | Does | Notes |
|---|---|---|
| Back chevron | Pops the navigation stack | **No unsaved-changes confirmation** — exits immediately, discarding any in-progress work |
| Save | Shows a name-entry alert (blank → auto-generates "Level N"), then commits | See "Save flow" below — has a known navigation bug |

### Global rule toggles
- Classic and Non-Consecutive are mutually exclusive (`toggleRule`); at least one is always forced on if both would end up off.
- King and Knight are independent, additive toggles.
- Not explained anywhere in the in-app Encyclopedia's Level Builder section.

### Tool palette (Erase, Digit, Thermo, Arrow, Cage, Odd-Even, Kropki)
Switching tools auto-commits any in-progress shape and clears any pending Kropki first-tap.

- **Erase**: tap any cell to clear its digit/parity, **and removes the entire thermo/arrow/cage/dot that touches that cell** — not just that cell's piece of it. This is the *only* way to delete a placed shape or a sandwich clue; there's no per-shape delete button and no undo in the builder.
- **Digit**: tap places the currently-selected digit (chosen via a contextual picker) as a clue. Capped at 9 placements of the same digit, enforced silently — hitting the cap just does nothing, no feedback shown.
- **Thermo / Arrow**: built via **sequential taps, not a drag gesture**. Each new tap must be king-adjacent (8-directional) to the *last* tapped cell, can't repeat a cell already in the path, and is capped by length: Thermo 5 (if Non-Consecutive active) or 9, Arrow **9** (fixed — see note below; an invalid tap triggers a brief 0.3s "invalid" flash and is rejected without altering the path.
- **Cage**: sequential taps too, but adjacency is checked against *any* cell already in the path, not just the last. Capped at 9 cells. Finishing (switching tools, or the "Finish Shape" control) opens the Cage Sum alert rather than committing immediately.
- **Odd-Even**: tap sets a cell's parity directly (immediate, no shape-building), via a contextual sub-picker.
- **Kropki**: two-tap placement. First tap marks a "first cell"; second tap places a dot (color from the contextual picker) if orthogonally adjacent to the first. If not adjacent, no dot is placed and the second tap silently becomes the new "first cell" instead — no error shown.
- While a Thermo/Arrow/Cage is mid-draw, contextual "Cancel"/"Finish Shape" controls appear; Finish is disabled until at least 2 cells are in the path.

**Note on Arrow length**: `GAME_LOGIC_AND_RULES.md` §6.1 (as of an earlier scan) flagged the Arrow length cap as an unsatisfiable value of 10 (a single-digit bulb can't sum a 10-cell line). **That's already been fixed** — `getMaxLength(for: .arrow)` returns 9 in the current code (inline comment: `"FIX: Phase 1 Bug #2"`). The reference doc needs updating to match; don't re-introduce the old value.

### Sandwich clue buttons (perimeter of the grid)
Tap opens an alert to enter a sum (valid: 0 or 2-35, save disabled while invalid); Erase tool + tap removes a clue instead.

### Save flow — fixed 2026-09-19
1. Save → name-entry alert → `commitSave(context:)`.
2. Edit mode (entered via `.levelBuilderEdit(existingLevel)`) updates the existing `CustomSudokuLevel` in place; create mode inserts a new one.
3. Success message: **new level** → `"Level saved successfully!"`; **edit** → `"Updated successfully!"`.
4. `LevelBuilderView`'s dismiss-handler checked `message == "Saved successfully!" || message == "Updated successfully!"` to decide whether to navigate back. The new-level string didn't match ("Level saved successfully!" vs. the checked "Saved successfully!") — so saving a brand-new level showed the success dialog, but tapping OK did not navigate back (the level *was* saved correctly; only the auto-navigation was broken). **Fixed 2026-09-19**: the check now matches the actual string ("Level saved successfully!"), so both the create and edit paths navigate back correctly.

### Validate button
Runs `HumanLogicSolver` on the current board (`checkValidation()`), shows a result overlay. Disabled while running.

**Encyclopedia inaccuracy**: the Encyclopedia's "Verification" entry claims every custom level is "verified by a logical solver to guarantee it is 100% uniquely solvable." This overstates it two ways: validation is **opt-in** (you must tap Validate; it's not required to Save — an unvalidated or unsolvable level saves with zero warning), and it does **not** guarantee unique solvability (the in-app footnote text says the opposite). See in-app fix section below.

### Edit mode
Entered via a non-nil `existingLevel`; `hydrateFrom(_:)` restores digits, toggles, all shapes/dots, and clues. No visual indicator distinguishes "editing X" from "creating new" beyond the pre-filled board.

---

## 3. Navigation & Menus

### `MainMenuView`
| Control | Does | Notes |
|---|---|---|
| Continue card | Jumps into the in-progress level/custom level | Only shown when `activeSession` is set; for a custom-level session, if the level lookup fails, the card **silently doesn't render** — no error |
| Play Campaign | Opens Level Selection | |
| Level Builder | Opens the builder (create mode) | |
| My Custom Levels | Opens the custom levels list | |
| Book icon | Opens the Encyclopedia (`HowToPlayView`) | **The only entry point to the Encyclopedia** from outside a level — inside a level, use the "Full Guide" button in the Rules sheet instead |
| Gear icon | Opens `SettingsView` as a sheet | Calls `refreshLevelState()` on dismiss |

### `LevelSelectionView`
| Control | Does | Notes |
|---|---|---|
| "?" info button | Opens `LevelIconsInfoView` (static rule-icon legend) | |
| Level card tap | Opens `LevelPreviewModal`, **including for locked levels** | Deliberate — lets you see the lock message. Tapping "Play" in the modal defers the actual navigation push until ~0.2s after the sheet's dismiss animation, to avoid visual conflict |
| Filter button (bottom bar) | Cycles All → Solved → Unsolved → one filter per rule type → All | Filters match only a level's **primary** rule type — a hybrid level (e.g. Killer + Non-Consecutive) only shows under one filter, silently excluded from the other |
| Auto-scroll to first unsolved | Automatic on appear/filter-change/data-load | Not a button |
| `showGatekeeperAlert` | **Dead code** — the state flag and alert block exist but nothing ever sets the flag true; this alert can never appear. The real 250-barrier messaging lives entirely in `LevelPreviewModal` instead. Don't "fix" this expecting it to do anything — either wire it up deliberately or remove it. |

### `LevelPreviewModal`
| Control | Does | Notes |
|---|---|---|
| Start/Continue/Restart button | Unsolved: "Start Level" (no prior progress) or "Continue Level" (has progress). Solved: "Restart Level" — shows a confirmation alert, then on confirm calls `resetLevelProgress` and plays | **Fixed 2026-09-19**: now confirms, matching the in-game pause menu's Restart. `bestTime`/`lastSolvedTime` are preserved by the reset logic; board/notes/colors/time are cleared |
| Cancel | Dismisses | |
| Locked-level message | Two variants: `id > 250 && !isMilestoneOneComplete` → "Complete all levels 1-250 first!"; otherwise → "Complete Level {id-1} to unlock" | Verified to match the real unlock algorithm exactly |

### `CustomLevelsListView`
| Control | Does | Notes |
|---|---|---|
| Row tap | Opens the level for play | |
| "⋯" → Edit | Opens the builder in edit mode | |
| "⋯" → Delete | Deletes the level from SwiftData | **Fixed 2026-09-19**: now shows a confirmation alert (Cancel/Delete) naming the level before deleting — previously deleted immediately with zero confirmation |

### `SettingsView` — actual effect vs. label, verified against code
| Setting | Actual effect | Label/Encyclopedia accurate? |
|---|---|---|
| Minimal Highlight | Gates all Restriction/Potential highlight logic — when on, neither ever runs | Yes |
| Highlight Mode (Restriction/Potential) | Switching to Potential for the first time shows a one-time "Are you sure?" warning before applying | Yes |
| Highlight Same Number / Same Note | Gates `.sameValue`/`.sameNote` highlight cases directly | Yes |
| Show Mistakes (Never/Immediate/When Board Full) | Gates *visual reveal* only — does not affect mistake *counting* | Yes |
| Enable Mistake Limit (3 Strikes) | `@AppStorage`-backed (bypasses SwiftData). When off, mistakes are **never counted at all**, not just never game-over'd | Fixed 2026-09-19 — Encyclopedia now states this explicitly |
| Show Hint Button | `@AppStorage`-backed. Hides the hint button — but it's **always hidden on custom levels regardless of this toggle** | Fixed 2026-09-19 — custom-level exception now mentioned |
| Disable Completed Digits | Passed straight to `NumberPadView` | Yes |
| Show Combination Helpers | Gates helper-button visibility **and** whether cage combinations auto-populate by default when a cage is first selected | Fixed 2026-09-19 — auto-population side effect now mentioned |
| Auto-Filter Combinations | Triggers/gates `applyCombinationAutoFilter()` | Yes |
| Hint Target (Selected/Random Cell) | Drives the branch in `useHint()` | Yes |
| Theme | Applied at the `WindowGroup` level | Yes |
| Contact Us | Opens Mail composer, or an alert with a "Copy Support Email" fallback if Mail isn't configured | Fallback not documented, minor |
| Unlock All Levels (Dev Only) | `#if DEBUG` only, writes `devAllUnlocked` | N/A, not shipped |

### `LevelIconsInfoView`
Static, self-contained legend (icon + name + one-line description per rule type). No logic, documents itself.

---

## 4. Gaps & Issues Found (2026-09-19 audit) — status tracker

Ranked by player impact. Update the status column as these get addressed.

| # | Issue | Type | Status |
|---|---|---|---|
| 1 | Custom level Delete has no confirmation | Bug/risk (missing safety) | Fixed 2026-09-19 — confirmation alert added |
| 2 | "Restart Level" in preview modal (solved levels) has no confirmation | Bug/risk (missing safety) | Fixed 2026-09-19 — confirmation alert added, matching pause-menu restart |
| 3 | Level Builder save-success navigation broken for new levels (string mismatch) | Bug | Fixed 2026-09-19 — corrected the string check |
| 4 | Encyclopedia "Verification" claim overstates automatic/guaranteed uniqueness | Doc inaccuracy | Fixed 2026-09-19 |
| 5 | Encyclopedia "Drawing Shapes" says "drag" — actual mechanic is sequential taps | Doc inaccuracy | Fixed 2026-09-19 |
| 6 | Encyclopedia "tap the cage sum to edit" — no such feature exists | Doc inaccuracy | Fixed 2026-09-19 |
| 7 | Killer helper button, hint cooldown/errors, pause menu options, Rules/Settings buttons, "19" button, combination-helper overlays, Level Builder rule toggles, edit mode — undocumented in-app | Doc gap | Fixed 2026-09-19 (Encyclopedia additions) |
| 8 | Filter-by-rule-type silently excludes hybrid levels from single-rule filters | Doc gap (behavior itself may be intentional) | Documented here, not changed |
| 9 | `showGatekeeperAlert` dead code in `LevelSelectionView.swift` | Dead code | Documented here, not removed |
| 10 | GAME_LOGIC_AND_RULES.md's Arrow-length-cap bug claim is stale (already fixed) | Doc inaccuracy | Fixed 2026-09-19 |
