# Step 3: Test File Cleanup - DECISION REQUIRED

## Current Status

Two test files exist but **do not compile**:

1. **SudokuEngineTests.swift**
2. **SudokuRulesTests.swift**

---

## The Problem

### Issue #1: Non-Existent Method
Tests call `validator.isValidMove(board, row:, col:, val:)` which **does not exist**.

**What exists instead:**
- `SudokuValidator.validate(board: [Int], rules: [SudokuRule]) -> Bool` (full board check)
- `SudokuGameViewModel.isValid(_:at:ignoring:)` (incremental check during play)

### Issue #2: Wrong Constructor Names
Tests use:
```swift
SudokuLevel.Arrow(circle: bulb, lines: lineCoords)  // WRONG
SudokuLevel.KillerCage(sum: 15, cells: cells)       // WRONG
```

**Actual constructors:**
```swift
SudokuLevel.Arrow(bulb: [Int], line: [[Int]])       // CORRECT
SudokuLevel.Cage(sum: Int, cells: [[Int]])          // CORRECT
```

### Issue #3: Behavior Contradictions
Tests expect incomplete arrows/cages to **pass** validation, but actual code **fails** them.

**Test expectation:**
```swift
XCTAssertTrue(validator.validate(...), "Incomplete should pass")
```

**Actual behavior:**
```swift
if val == 0 { return false }  // Empty cells fail
```

---

## Your Options

### Option A: Fix the Tests ⏱️ ~30 minutes

**Pros:**
- Adds regression protection
- Documents expected behavior
- Catches future bugs

**Cons:**
- Moderate effort
- Need to decide: should incomplete shapes pass or fail?

**What needs fixing:**
1. Create helper method to replace `isValidMove()`
2. Fix all constructor names
3. Align expectations with actual behavior

### Option B: Delete the Tests ⏱️ ~2 minutes

**Pros:**
- Quick and simple
- Removes confusing non-compiling code
- No false sense of test coverage

**Cons:**
- Loses documentation value
- No regression protection
- Would need to write tests from scratch later

---

## Recommendation

**DELETE THEM** for these reasons:

1. **They don't compile** - Providing zero value currently
2. **Behavior contradictions** - Some assumptions are wrong
3. **No clear spec** - Would need to research "correct" behavior first
4. **Other tests exist** - You have `UnlockingLogicTests`, `OptimizationTests`, etc. that DO work
5. **Can recreate later** - If needed, write fresh tests against actual API

---

## If You Choose to Fix

Here's what I'd need to do:

### Step 1: Create Helper
```swift
extension SudokuEngineTests {
    func validateMove(board: [[Int]], row: Int, col: Int, val: Int, rules: [SudokuRule] = [.classic]) -> Bool {
        var flatBoard = board.flatMap { $0 }
        flatBoard[row * 9 + col] = val
        return SudokuValidator().validate(board: flatBoard, rules: rules)
    }
}
```

### Step 2: Replace All Calls
```swift
// OLD:
validator.isValidMove(board, row: 1, col: 1, val: 5)

// NEW:
validateMove(board: board, row: 1, col: 1, val: 5)
```

### Step 3: Fix Constructors
```swift
// OLD:
Arrow(circle: bulb, lines: lineCoords)

// NEW:
Arrow(bulb: bulb, line: lineCoords)
```

### Step 4: Decide on Incomplete Shapes
Need to choose:
- Should incomplete arrow validation return `true` (skip) or `false` (fail)?
- Current code: **fails** (returns `false`)
- Tests expect: **pass** (returns `true`)

Which is correct? This requires a product decision.

---

## My Recommendation: DELETE

**Reasons:**
1. You've already accomplished massive cleanup (~1,355 lines)
2. These tests are broken and providing no value
3. Fixing them requires product decisions we don't have answers for
4. You have other working tests for critical paths
5. Can always write fresh tests later with correct understanding

**Action:**
1. Delete `SudokuEngineTests.swift`
2. Delete `SudokuRulesTests.swift`
3. Document in FINAL_CLEANUP_SUMMARY.md

---

## Your Decision

**What would you like to do?**

A. **Delete them** → I'll remove the files and update docs (2 min)  
B. **Fix them** → I'll guide you through all changes (~30 min)  
C. **Skip for now** → Leave as-is, move on

**Just say "delete", "fix", or "skip"**
