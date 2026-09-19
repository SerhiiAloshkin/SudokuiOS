# Step 3: Phase 2 Cleanup - Fix or Delete Broken Tests

## Overview

`SudokuEngineTests.swift` and `SudokuRulesTests.swift` currently **do not compile** against the live codebase.

**Issues found:**
1. Call non-existent `validator.isValidMove()` method
2. Use wrong constructor names (`Arrow(circle:lines:)` vs `Arrow(bulb:line:)`)
3. Use wrong type name (`KillerCage` vs `Cage`)
4. Test assumptions contradict actual validator behavior

---

## Decision Required

### Option A: Fix the Tests
**Effort:** Medium  
**Value:** High - Provides regression protection  
**Risk:** Low - We'll align with actual APIs

**What needs fixing:**
1. Replace `isValidMove()` calls with actual API
2. Fix constructor names to match real types
3. Align test expectations with actual behavior

### Option B: Delete the Tests  
**Effort:** Low  
**Value:** Low - Removes misleading "coverage"  
**Risk:** None - They don't run anyway

**If tests provide no value or are testing wrong behavior anyway**

---

## Recommendation: Option A (Fix Them)

The test *intent* is good - they're testing important rule logic. Let's fix them properly.

---

## Detailed Fix Plan

### File 1: `SudokuEngineTests.swift`

#### Problem 1: Non-existent `isValidMove()` method

**Current code (doesn't compile):**
```swift
let sameBoxInvalid = validator.isValidMove(board, row: 1, col: 1, val: 5)
```

**What exists in reality:**
- `SudokuValidator.validate(board: [Int], rules: [SudokuRule]) -> Bool`
- `SudokuGameViewModel.isValid(_:at:ignoring:)` (for incremental checks)

**Fix approach:**
Use the actual `validate()` method with proper board setup:

```swift
// Instead of: validator.isValidMove(board, row: 1, col: 1, val: 5)
// Do this:
var boardArray = board.flatMap { $0 }
boardArray[1 * 9 + 1] = 5
let result = validator.validate(board: boardArray, rules: [.classic])
XCTAssertFalse(result, "Should be invalid")
```

#### Problem 2: Wrong constructor names

**Current code:**
```swift
SudokuLevel.Arrow(circle: bulb, lines: lineCoords)
SudokuLevel.KillerCage(sum: 15, cells: cells)
```

**Real constructors:**
```swift
SudokuLevel.Arrow(bulb: [Int], line: [[Int]])
SudokuLevel.Cage(sum: Int, cells: [[Int]])
```

**Fix:** Update all constructor calls

#### Problem 3: Behavior contradiction

Tests expect incomplete arrows/cages to pass validation, but actual code fails them.

**Current test expectation:**
```swift
// Incomplete arrow
XCTAssertTrue(validator.validate(...), "Incomplete should pass")
```

**Actual validator behavior (from GAME_LOGIC_AND_RULES.md §1.4):**
```swift
if val == 0 { return false }  // Empty cells fail validation
```

**Decision needed:** Which is correct?
- If incomplete SHOULD pass: Fix validator
- If incomplete SHOULD fail: Fix test expectations

**Recommendation:** Incomplete arrows/cages should FAIL (current behavior is correct).  
Tests should be updated to `XCTAssertFalse()` for incomplete shapes.

---

### File 2: `SudokuRulesTests.swift`

Same issues as `SudokuEngineTests.swift`:
- Uses non-existent `isValidMove()`
- Wrong constructor names
- Wrong behavior assumptions

Apply same fixes.

---

## Concrete Implementation

### Step 1: Add helper method to convert 2D board to flat array

```swift
extension SudokuEngineTests {
    func boardToArray(_ board: [[Int]]) -> [Int] {
        return board.flatMap { $0 }
    }
    
    func validateMove(board: [[Int]], row: Int, col: Int, val: Int, rules: [SudokuRule] = [.classic]) -> Bool {
        var flatBoard = boardToArray(board)
        flatBoard[row * 9 + col] = val
        return SudokuValidator().validate(board: flatBoard, rules: rules)
    }
}
```

### Step 2: Replace all `isValidMove()` calls

```swift
// OLD (doesn't compile):
let invalid = validator.isValidMove(board, row: 1, col: 1, val: 5)

// NEW (works):
let invalid = validateMove(board: board, row: 1, col: 1, val: 5)
```

### Step 3: Fix constructor names

```swift
// OLD:
let arrow = SudokuLevel.Arrow(circle: bulb, lines: lineCoords)
let cage = SudokuLevel.KillerCage(sum: 15, cells: cells)

// NEW:
let arrow = SudokuLevel.Arrow(bulb: bulb, line: lineCoords)
let cage = SudokuLevel.Cage(sum: 15, cells: cells)
```

### Step 4: Fix incomplete-shape test expectations

```swift
// OLD:
XCTAssertTrue(validator.validate(...), "Incomplete arrow should pass")

// NEW (aligns with actual behavior):
XCTAssertFalse(validator.validate(...), "Incomplete arrow should fail per §1.4")
```

---

## Files to Modify

- [ ] `SudokuEngineTests.swift` - Fix API calls, constructors, expectations
- [ ] `SudokuRulesTests.swift` - Same fixes

**OR**

- [ ] Delete both files if fixing isn't worth the effort

---

## Effort Estimate

**If fixing:**
- ~30-60 minutes to update all test methods
- Verify each test actually passes
- Document any behavioral assumptions

**If deleting:**
- 2 minutes, delete the files
- Remove references from Xcode project

---

## After This Step

Once Phase 2 is complete:
- ✅ Phase 1: Dead managers deleted
- ✅ Phase 2: Tests fixed or deleted  
- ➡️ Phase 3: Investigate `PointingPairsSolver.swift` (513 lines, unclear if used)

---

**Decision time:** Fix or delete? Let me know and I'll execute.
