# Step 2: Concrete Bug Fixes - READY TO APPLY

All 3 bugs have been located and verified. Here are the exact fixes.

---

## Bug #1: Ad-Unlock Not Durable

**File:** `LevelViewModel.swift`  
**Line:** 739-789 (in `recalculateLocks()` function)

### Current Code (Lines 739-789)
```swift
private nonisolated static func recalculateLocks(for levels: inout [SudokuLevel], hasRemovedAds: Bool, debugUnlock: Bool) {
    let endOfFirstSection = min(250, levels.count)
    let firstSectionSolved = levels[0..<endOfFirstSection].allSatisfy { $0.isSolved }
    
    for i in 0..<levels.count {
        if debugUnlock {
            levels[i].isLocked = false
            continue
        }
        
        let levelID = levels[i].id
        
        // Unlocked Criteria:
        // 1. Is Solved -> Always Unlocked
        if levels[i].isSolved {
            levels[i].isLocked = false
            continue
        }
        
        // 2. Level 1 is always unlocked
        if levelID == 1 {
            levels[i].isLocked = false
            continue
        }
        
        // 3. If user removed ads, unlock everything
        if hasRemovedAds {
            levels[i].isLocked = false
            continue
        }
        
        // 4. Sequential unlocking: Only unlock if previous level is solved
        // For level N, check if level N-1 is solved
        if i > 0 && levels[i - 1].isSolved {
            // Section 1 (1-250): Previous level solved = unlock
            if levelID <= 250 {
                levels[i].isLocked = false
            } else {
                // Section 2 (251-600): Must also have completed all of section 1
                if firstSectionSolved {
                    levels[i].isLocked = false
                } else {
                    levels[i].isLocked = true
                }
            }
        } else {
            // Previous level not solved = locked
            levels[i].isLocked = true
        }
    }
}
```

### Fixed Code
Add this check AFTER the "removed ads" check, BEFORE the sequential unlocking logic:

```swift
private nonisolated static func recalculateLocks(for levels: inout [SudokuLevel], hasRemovedAds: Bool, debugUnlock: Bool) {
    let endOfFirstSection = min(250, levels.count)
    let firstSectionSolved = levels[0..<endOfFirstSection].allSatisfy { $0.isSolved }
    
    for i in 0..<levels.count {
        if debugUnlock {
            levels[i].isLocked = false
            continue
        }
        
        let levelID = levels[i].id
        
        // Unlocked Criteria:
        // 1. Is Solved -> Always Unlocked
        if levels[i].isSolved {
            levels[i].isLocked = false
            continue
        }
        
        // 2. Level 1 is always unlocked
        if levelID == 1 {
            levels[i].isLocked = false
            continue
        }
        
        // 3. If user removed ads, unlock everything
        if hasRemovedAds {
            levels[i].isLocked = false
            continue
        }
        
        // 4. Ad-unlocked levels stay unlocked (FIX FOR BUG #1)
        if levels[i].isAdUnlocked {
            levels[i].isLocked = false
            continue
        }
        
        // 5. Sequential unlocking: Only unlock if previous level is solved
        // For level N, check if level N-1 is solved
        if i > 0 && levels[i - 1].isSolved {
            // Section 1 (1-250): Previous level solved = unlock
            if levelID <= 250 {
                levels[i].isLocked = false
            } else {
                // Section 2 (251-600): Must also have completed all of section 1
                if firstSectionSolved {
                    levels[i].isLocked = false
                } else {
                    levels[i].isLocked = true
                }
            }
        } else {
            // Previous level not solved = locked
            levels[i].isLocked = true
        }
    }
}
```

**Change Summary:** Add 4 lines after the "removed ads" check:
```swift
// 4. Ad-unlocked levels stay unlocked (FIX FOR BUG #1)
if levels[i].isAdUnlocked {
    levels[i].isLocked = false
    continue
}
```

---

## Bug #2: Arrow Line Length Cap Too High

**File:** `LevelBuilderViewModel.swift`  
**Line:** 406

### Current Code
```swift
case .arrow:
    return 10 // 1 head + max 9 body cells (sum ≤ 9)
```

### Problem
The comment says "sum ≤ 9" but:
- Bulb (head) holds a single digit: 1-9
- If line has 10 cells, minimum sum = 10 (ten 1's)
- But 10 > 9, impossible!

Actually, even 9 cells in the line might be too many, but let's check the math:
- 1 bulb cell + 9 line cells = 10 total cells
- Bulb value max = 9
- Line with 1 cell = can equal bulb (1-9) ✅
- Line with 2 cells = min sum 1+2=3, max sum 8+9=17 ✅ (can hit any 3-17)
- Line with 9 cells = min sum 1+2+3+4+5+6+7+8+9 = 45, max also 45 (all same 9 distinct digits)
- But we need sum to be ≤9 for the bulb to hold it!

Wait, arrows CAN have repeating digits in the line (not subject to row/col/box rules). So:
- Line with 9 cells, all = 1 → sum = 9 ✅ This works!

So 9 IS valid (nine 1's = sum of 9). The current 10 is NOT (ten 1's = sum of 10).

### Fixed Code
```swift
case .arrow:
    return 9 // 1 head + max 8 body cells
```

**Change Summary:** Change `10` to `9` on line 406

---

## Bug #3: Custom Level ID Collision

**File:** `CustomSudokuLevel.swift`  
**Line:** 186

### Current Code
```swift
// Use unique negative ID from UUID hash to avoid collisions
let uniqueID = -abs(id.hashValue % 1_000) - 1
```

### Problem
- Only 1,000 buckets (% 1,000)
- Birthday paradox: 50% collision at ~40 levels, 99% at ~100 levels
- Progress is keyed by this ID
- Collision = wrong save data loaded!

### Fixed Code
```swift
// Use unique negative ID from UUID hash (full Int range)
let uniqueID = -abs(id.hashValue)
```

**Change Summary:** Remove the `% 1_000` and `-1` on line 186

**Why this works:**
- `Int.hashValue` returns full Int range (billions of values)
- Make it negative to distinguish from campaign levels (1-600 positive)
- Collision risk now negligible (same as UUID itself)

---

## Testing Plan

### Test Bug #1
```
1. Ensure levels 1-10 are solved, level 11 is NOT
2. Use ad-unlock on level 11
3. Verify: level 11 shows as unlocked ✅
4. Solve level 5 (unrelated, triggers refreshLocks)
5. Check level 11: should STILL be unlocked ✅ (CURRENTLY FAILS)
```

### Test Bug #2
```
1. Open Level Builder
2. Select Arrow tool
3. Tap bulb cell, then tap 9 more cells (10 total)
4. Should prevent 10th tap ✅
5. Maximum line should be 9 cells
```

### Test Bug #3
```
1. Create custom level A
2. Create custom level B  
3. Print their IDs (should be different large negative numbers)
4. Save progress on A (e.g., place some numbers)
5. Open level B
6. Progress should be independent (not mixed) ✅
```

---

## Summary of Changes

| File | Line | Change | Lines Changed |
|------|------|--------|--------------|
| `LevelViewModel.swift` | After 772 | Add `isAdUnlocked` check | +4 lines |
| `LevelBuilderViewModel.swift` | 406 | Change `10` to `9` | 1 line |
| `CustomSudokuLevel.swift` | 186 | Remove `% 1_000 - 1` | 1 line |

**Total:** 3 files, ~6 lines changed, 3 critical bugs fixed

---

Ready to apply? Reply "yes" and I'll make the changes.
