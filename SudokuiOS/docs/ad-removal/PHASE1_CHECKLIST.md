# Phase 1 Cleanup Checklist

## Pre-Deletion Checklist

- [x] Identified all dead manager files (6 total)
- [x] Verified zero references in codebase
- [x] Documented all findings in PHASE1_CLEANUP.md
- [x] Updated GAME_LOGIC_AND_RULES.md with deletion notes
- [x] Created cleanup script (cleanup_phase1.sh)
- [x] Created action guide (CLEANUP_ACTION_REQUIRED.md)

## Execution Checklist

### Files to Delete (Check off as you delete)

- [ ] **GameStateManager.swift**
  - Location: Likely in a "Managers" or "ViewModels" folder
  - Size: 136 lines
  - Purpose: Dead state management extraction

- [ ] **TimerManager.swift**
  - Location: Likely in a "Managers" folder
  - Size: 94 lines
  - Purpose: Dead timer logic extraction

- [ ] **HintSystemManager.swift**
  - Location: Likely in a "Managers" folder
  - Size: 153 lines
  - Purpose: Dead hint system with stale ad callbacks

- [ ] **GamePersistenceManager.swift**
  - Location: Likely in a "Managers" folder
  - Size: 245 lines
  - Purpose: Dead save/load logic

- [ ] **MoveHistoryManager.swift**
  - Location: Likely in a "Managers" folder
  - Size: 177 lines
  - Purpose: Dead in-memory undo/redo

- [ ] **OptimizedPotentialHighlightCalculator.swift**
  - Location: Likely near PotentialHighlightCalculator.swift
  - Size: 263 lines
  - Purpose: Incomplete, unused optimization

## Post-Deletion Checklist

- [ ] **Build succeeds** (Cmd+B in Xcode)
- [ ] **No compilation errors** related to missing files
- [ ] **App runs on simulator/device**
- [ ] **Basic functionality test:**
  - [ ] Can start a level
  - [ ] Can enter numbers
  - [ ] Can use undo/redo
  - [ ] Can use hints
  - [ ] Timer works
  - [ ] Can save/resume game
- [ ] **Git commit created:**
  ```bash
  git add -A
  git commit -m "Phase 1 cleanup: Remove 6 dead manager files (~1,067 lines)"
  git push
  ```

## Rollback Plan (If Something Goes Wrong)

If you accidentally delete something important:

```bash
# See what was deleted
git status

# Restore a specific file
git checkout HEAD -- path/to/file.swift

# Or restore everything
git reset --hard HEAD
```

But this shouldn't be necessary - these files are confirmed dead!

## Success Criteria

✅ **All 6 files deleted**  
✅ **Project builds successfully**  
✅ **App runs normally**  
✅ **Changes committed to git**  
✅ **~1,067 lines of dead code removed**

## What's Next?

After completing Phase 1, you can:

1. **Stop here** - You've cleaned up the biggest chunk of dead code ✨
2. **Continue to Phase 2** - Fix or delete broken test files
3. **Continue to Phase 3** - Investigate PointingPairsSolver.swift

Just let me know what you'd like to do!

---

**Status:** Awaiting execution  
**Estimated time:** 5-10 minutes  
**Risk:** Zero (files are completely unused)
