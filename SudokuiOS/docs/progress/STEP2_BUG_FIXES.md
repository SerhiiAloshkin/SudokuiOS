# Step 2: Fix the 3 Confirmed Bugs

These are **real bugs** identified in the game logic review (§6.1 of GAME_LOGIC_AND_RULES.md).

---

## Bug 1: Ad-Unlock Not Durable Across `refreshLocks()`

### Problem
**File:** `LevelViewModel.swift`  
**Severity:** 🔴 HIGH - User-facing bug with test reproduction  
**Impact:** User watches ad to unlock level → solves different level → original ad-unlocked level re-locks

### Current Behavior
```swift
// LevelViewModel.swift - recalculateLocks()
// Line ~739-789
func recalculateLocks() {
    // Does NOT check isAdUnlocked flag
    // So ad-unlocked levels get re-locked on next refresh
}
```

### Test That Proves It
`UnlockingLogicTests.testGapHandling` - already passing, exposes the bug

### Root Cause
- `unlockLevelViaAd()` sets `isLocked = false` directly
- But `recalculateLocks()` never reads `isAdUnlocked` flag
- Next call to `refreshLocks()` → runs `recalculateLocks()` → level re-locks

### Proposed Fix (Option A - Simplest)
Read the `isAdUnlocked` flag in `recalculateLocks()`:

```swift
func recalculateLocks() {
    for (i, level) in levels.enumerated() {
        // Existing checks...
        
        // ADD THIS CHECK before final "otherwise locked":
        if level.isAdUnlocked {
            level.isLocked = false
            continue
        }
        
        // Otherwise locked
        level.isLocked = true
    }
}
```

### Proposed Fix (Option B - Use Sticky Flag)
Make `isUnlocked` actually matter:

```swift
func recalculateLocks() {
    for (i, level) in levels.enumerated() {
        // Existing checks...
        
        // ADD THIS CHECK:
        if level.isUnlocked {
            level.isLocked = false
            continue
        }
        
        // Otherwise locked
        level.isLocked = true
    }
}

// And in unlockLevelViaAd():
func unlockLevelViaAd(_ levelID: Int) {
    guard let level = levels.first(where: { $0.id == levelID }) else { return }
    level.isLocked = false
    level.isAdUnlocked = true
    level.isUnlocked = true  // ADD THIS - makes it sticky
    saveUnlockState()
}
```

**Recommendation:** Option B - makes the sticky flag actually work as designed

---

## Bug 2: Arrow Line Length Cap of 10 is Unsatisfiable

### Problem
**File:** `LevelBuilderViewModel.swift`  
**Severity:** 🔴 HIGH - Can create mathematically impossible puzzles  
**Impact:** Builder allows arrow lines with 10 cells, but bulb can only hold 1-9

### Current Behavior
```swift
// LevelBuilderViewModel.swift
// Arrow line max length = 10
```

### Math Problem
- Bulb is 1 cell → holds 1 digit → max value = 9
- Line of 10 cells → minimum sum = 1+1+1+1+1+1+1+1+1+1 = 10
- 10 > 9 → **impossible to satisfy**
- Even if you use 1,2,3,4,5,6,7,8,9,0 that's still 45, way over 9

### Proposed Fix
Change the constant from 10 to 9:

```swift
// Find in LevelBuilderViewModel.swift
// Search for: "arrow" and "10"
// Change: maxLineLength = 10
// To:     maxLineLength = 9
```

Should be a single-line fix. Match Killer cage's max length of 9.

### Verification
After fix:
1. Try to create arrow with 10-cell line in builder → should prevent it
2. Max buildable arrow line = 9 cells → sum at most 1+2+3+4+5+6+7+8+9 = 45, which is > 9 but at least theoretically possible with repetition rules

**Wait...** Actually, even 9 cells might be too many. Let me recalculate:
- Max bulb value: 9
- If line has 9 distinct cells: minimum sum = 1+2+3+4+5+6+7+8+9 = 45
- But we need sum = 9 (the bulb value)
- Only way: use nine 1's? But Classic rules prevent duplicates...

**Actually need to find the real constraint in the codebase first.** Let me search for it.

---

## Bug 3: Custom Level ID Collision Risk

### Problem
**File:** `CustomSudokuLevel.swift`  
**Severity:** 🔴 HIGH - Data corruption as user creates more levels  
**Impact:** Only 1,000 buckets for ID; progress keyed by ID; collision = wrong save data

### Current Behavior
```swift
// CustomSudokuLevel.swift
var id: Int {
    return abs(uuid.hashValue) % 1000  // Only 1000 buckets!
}
```

### Math Problem
- Birthday paradox: 50% collision chance with ~40 custom levels
- 99% collision chance with ~100 custom levels
- Progress saved per-level using this ID
- Collision → wrong progress loaded/saved → data corruption

### Proposed Fix (Option A - Wider Hash)
Use full hash value (Int range):

```swift
var id: Int {
    return -abs(uuid.hashValue)  // Negative to distinguish from campaign levels
    // Standard levels: 1-600 (positive)
    // Custom levels: negative entire Int range
}
```

### Proposed Fix (Option B - Use UUID Directly)
Don't derive an Int ID at all; use UUID for persistence:

```swift
// This requires larger refactor - persistence system expects Int
// Not recommended for quick fix
```

**Recommendation:** Option A - simple, fixes the collision risk immediately

---

## Implementation Order

1. **Bug 2 first** - Find exact constant, verify math, one-line fix
2. **Bug 3 second** - Change hash formula, test with multiple custom levels
3. **Bug 1 third** - Requires understanding unlock flow, has existing tests

---

## Testing After Fixes

### Bug 1 - Ad Unlock Durability
```
1. Lock levels by not solving sequentially
2. Use ad-unlock on a gapped level
3. Solve a different level (triggers refreshLocks)
4. Check: original ad-unlocked level should STAY unlocked ✅
```

### Bug 2 - Arrow Line Length
```
1. Open Level Builder
2. Try to create arrow with max-length line
3. Should cap at 9 cells (or whatever new max is)
4. Should not allow mathematically impossible arrows ✅
```

### Bug 3 - Custom Level IDs
```
1. Create 2 custom levels
2. Check their IDs are different (and negative)
3. Save progress on level A
4. Load level B
5. Progress should be independent ✅
```

---

## Files to Modify

- [ ] `LevelViewModel.swift` - Bug 1 (ad-unlock)
- [ ] `LevelBuilderViewModel.swift` - Bug 2 (arrow length) 
- [ ] `CustomSudokuLevel.swift` - Bug 3 (ID collision)

**Ready to implement?** Let me know and I'll help with the actual code changes.
