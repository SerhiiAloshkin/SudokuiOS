# Sudoku Game — Repo Root

This is the git/Xcode project root (`.git`, `SudokuiOS.xcodeproj` live here). The actual app
source, SwiftData models, views, tests, and the full project instructions all live one level
down, in **`SudokuiOS/CLAUDE.md`** — read that file, not this one, for anything about the app
itself (architecture, conventions, the documentation-organization policy, build/testing rules).

This root-level file exists only so a Claude Code session starting *here* (rather than in
`SudokuiOS/`) still discovers project instructions instead of finding nothing. If you're seeing
this, `cd SudokuiOS` (or just open `SudokuiOS/CLAUDE.md`) before doing anything else.

Other things at this level, not covered by the inner CLAUDE.md: `Package.swift` and a
`logical_solver.py` / `test_logical_solver.py` / `run_sandwich_test.py` Python reference
implementation, plus a top-level `SudokuiOSTests/` and `Tests/` — distinct from
`SudokuiOS/SudokuiOSTests/`, which is the real, wired-in test target. If you touch any of these,
verify first which ones are actually part of the active Xcode scheme before assuming they run.
