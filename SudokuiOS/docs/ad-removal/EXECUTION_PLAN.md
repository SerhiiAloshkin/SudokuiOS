# Complete Cleanup Execution Plan

## Status: Ready to Execute

All preparation is complete. Follow these steps in order.

---

## ✅ Step 1: Delete 6 Dead Files (~5 minutes)

**See:** `DELETE_THESE_FILES.md`

### Quick Instructions
Open Xcode → Project Navigator → Search for and delete:
1. GameStateManager.swift
2. TimerManager.swift
3. HintSystemManager.swift
4. GamePersistenceManager.swift
5. MoveHistoryManager.swift
6. OptimizedPotentialHighlightCalculator.swift

### Verification
```bash
# Build should succeed
Cmd+B in Xcode

# App should run normally
Cmd+R in Xcode
```

### Commit
```bash
git add -A
git commit -m "Phase 1: Delete 6 dead manager files (~1,067 lines)"
```

**Status:** [ ] Complete

---

## ✅ Step 2: Fix 3 Critical Bugs (~10 minutes)

**See:** `STEP2_FIXES_READY.md`

### Bug #1: Ad-unlock durability (LevelViewModel.swift)
**Line:** After 772  
**Add:**
```swift
// 4. Ad-unlocked levels stay unlocked (FIX FOR BUG #1)
if levels[i].isAdUnlocked {
    levels[i].isLocked = false
    continue
}
```

### Bug #2: Arrow line length (LevelBuilderViewModel.swift)
**Line:** 406  
**Change:** `return 10` → `return 9`

### Bug #3: Custom level ID collision (CustomSudokuLevel.swift)
**Line:** 186  
**Change:** `let uniqueID = -abs(id.hashValue % 1_000) - 1`  
**To:** `let uniqueID = -abs(id.hashValue)`

### Verification
Run the test plans in `STEP2_FIXES_READY.md`

### Commit
```bash
git add -A
git commit -m "Fix 3 critical bugs: ad-unlock durability, arrow length cap, custom level ID collision"
```

**Status:** [ ] Complete

---

## ✅ Step 3: Fix or Delete Broken Tests (~30 minutes)

**See:** `STEP3_TEST_CLEANUP.md`

### Decision Required
- [ ] Option A: Fix the tests (recommended, ~30 min)
- [ ] Option B: Delete the tests (~2 min)

### If Fixing
Files to modify:
1. `SudokuEngineTests.swift`
2. `SudokuRulesTests.swift`

Changes needed:
- Replace `isValidMove()` with actual API
- Fix constructor names (Arrow, Cage)
- Update expectations for incomplete shapes

### If Deleting
Just delete both files from Xcode.

### Commit
```bash
# If fixed:
git add -A
git commit -m "Phase 2: Fix broken test files to match current APIs"

# If deleted:
git add -A
git commit -m "Phase 2: Remove non-compiling test files"
```

**Status:** [ ] Complete

---

## Summary Checklist

### Work Completed
- [x] Phase 1 preparation docs created
- [x] Bug fixes identified and documented
- [x] Test cleanup plan created
- [x] All fixes verified in source code

### Execution Checklist
- [ ] Step 1: Delete 6 dead files
- [ ] Step 2: Fix 3 bugs
- [ ] Step 3: Fix or delete tests
- [ ] All builds pass (Cmd+B)
- [ ] App runs correctly (Cmd+R)
- [ ] All changes committed to git

### Expected Outcome
✅ ~1,067 lines of dead code removed  
✅ 3 critical bugs fixed  
✅ Tests either working or removed (no broken tests)  
✅ Codebase significantly cleaner  
✅ Documentation (GAME_LOGIC_AND_RULES.md) up to date

---

## Optional Phase 4: Investigate PointingPairsSolver

**Not part of this cleanup, but noted for future:**
- `PointingPairsSolver.swift` - 513 lines, no confirmed call sites
- Contains duplicate Kropki logic
- Phase 3 candidate for deletion

**Recommendation:** Verify usage first, then delete if unused.

---

## Time Estimate

| Step | Time | Difficulty |
|------|------|------------|
| Step 1: Delete files | 5 min | Easy |
| Step 2: Fix 3 bugs | 10 min | Easy |
| Step 3: Fix tests | 30 min | Medium |
| Step 3: Delete tests | 2 min | Easy |
| **Total (fix path)** | **45 min** | Easy-Medium |
| **Total (delete path)** | **17 min** | Easy |

---

## Ready to Begin?

1. Open Xcode
2. Start with Step 1 (file deletion)
3. Follow the checklists in each document
4. Come back here to track progress

**All documentation is prepared. You're ready to execute!**
