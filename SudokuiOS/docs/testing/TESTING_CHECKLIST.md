# Testing Checklist - Ad Removal & Sequential Unlock

## Pre-Testing Setup
- [ ] Clean build the app
- [ ] Clear app data (fresh install state) or use simulator
- [ ] Verify you're testing without "Remove Ads" IAP activated
- [ ] Verify you're NOT in debug mode (devAllUnlocked = false)

---

## Test 1: Initial App State
**Goal:** Verify only Level 1 is unlocked on fresh install

### Steps:
1. Launch app for the first time
2. Navigate to level selection

### Expected Results:
- [ ] Level 1 shows as unlocked (blue gradient)
- [ ] Level 2 shows as locked (gray)
- [ ] All other levels show as locked
- [ ] No ads appear during navigation

---

## Test 2: Sequential Unlocking
**Goal:** Verify levels unlock one at a time

### Steps:
1. Tap Level 1
2. Complete Level 1 successfully
3. Return to level grid

### Expected Results:
- [ ] Level 1 shows green checkmark (solved)
- [ ] Level 2 is now unlocked (blue gradient)
- [ ] Level 3 remains locked (gray)
- [ ] **NO AD appears after completing Level 1**
- [ ] **NO AD appears when clicking "Next Level"**

---

## Test 3: Locked Level Interaction
**Goal:** Verify locked levels show helpful message

### Steps:
1. Tap Level 3 (which should be locked)
2. Read the preview modal

### Expected Results:
- [ ] Preview shows dimmed board with lock icon
- [ ] Message says "Complete Level 2 to unlock"
- [ ] Explanation text about sequential progression
- [ ] **NO "Unlock with Ad" button appears**
- [ ] Only "Cancel" button is available

---

## Test 4: Starting a Level (No Ads)
**Goal:** Verify no ads when starting levels

### Steps:
1. Tap Level 2 (unlocked level)
2. Click "Start Level" button
3. Observe what happens

### Expected Results:
- [ ] Level starts immediately
- [ ] **NO AD appears**
- [ ] Game loads and is playable
- [ ] Timer starts correctly

---

## Test 5: Continuing a Level (No Ads)
**Goal:** Verify no ads when continuing in-progress levels

### Steps:
1. Start Level 2
2. Make some moves (don't complete)
3. Exit to grid
4. Tap Level 2 again
5. Click "Continue Level"

### Expected Results:
- [ ] Preview shows "In Progress • [time]"
- [ ] Button says "Continue Level"
- [ ] **NO AD appears when clicking Continue**
- [ ] Game resumes with your progress intact

---

## Test 6: Victory Flow (No Ads)
**Goal:** Verify no ads in victory overlay

### Steps:
1. Complete Level 2
2. Observe victory overlay
3. Click "Next Level"

### Expected Results:
- [ ] Victory overlay appears with praise word
- [ ] Shows time and stats
- [ ] Shows "Next Challenge: Level 3"
- [ ] **NO AD appears when clicking "Next Level"**
- [ ] Navigates directly to Level 3

---

## Test 7: Restarting Solved Level (No Ads)
**Goal:** Verify no ads when restarting

### Steps:
1. Tap a solved level (e.g., Level 1)
2. Click "Restart Level"

### Expected Results:
- [ ] **NO AD appears**
- [ ] Level starts fresh (all progress cleared)
- [ ] Board shows only clues
- [ ] Timer starts at 0:00

---

## Test 8: Rapid Level Progression
**Goal:** Verify smooth flow through multiple levels

### Steps:
1. Complete Levels 1-5 in sequence
2. Use "Next Level" button after each victory
3. Note any interruptions

### Expected Results:
- [ ] Each level unlocks after previous is solved
- [ ] **NO ADS appear at any point**
- [ ] No cooldown delays
- [ ] Smooth transitions between levels
- [ ] Progress saves correctly

---

## Test 9: Section Gate (Level 251)
**Goal:** Verify gate still works correctly

### Steps:
1. Use debug mode or manually solve levels 1-249
2. Check Level 251 lock status
3. Complete Level 250
4. Check Level 251 again

### Expected Results:
- [ ] Level 251 is locked until ALL 1-250 completed
- [ ] Tapping Level 251 shows "Complete all levels 1-250 first!" message
- [ ] After completing Level 250 (and all before), Level 251 unlocks
- [ ] **NO ADS during any of this**

---

## Test 10: Remove Ads IAP
**Goal:** Verify IAP still works (even though no ads)

### Steps:
1. Fresh install OR clear progress
2. Activate "Remove Ads" IAP (simulate purchase)
3. Navigate to level grid

### Expected Results:
- [ ] ALL 600 levels show as unlocked (blue gradient)
- [ ] Can start any level immediately
- [ ] No ads show (but they weren't showing anyway)
- [ ] IAP state persists across app restarts

---

## Test 11: Debug Mode
**Goal:** Verify debug unlock still works

### Steps:
1. Enable debug mode: `UserDefaults.standard.set(true, forKey: "devAllUnlocked")`
2. Restart app
3. Navigate to level grid

### Expected Results:
- [ ] ALL levels show as unlocked
- [ ] Can play any level
- [ ] No ads appear

---

## Test 12: Edge Cases

### Test 12A: No Internet Connection
**Steps:**
1. Turn off WiFi and cellular data
2. Try all flows from above

**Expected:**
- [ ] App works normally (no ads means no dependency on network)
- [ ] All gameplay functions work offline

### Test 12B: Skipped Levels
**Steps:**
1. Manually mark Level 5 as solved (skip Levels 2-4)
2. Check which levels are unlocked

**Expected:**
- [ ] Only Level 1 and Level 6 should be unlocked
- [ ] Levels 2-4 remain locked
- [ ] Must go back and solve them sequentially

### Test 12C: Custom Levels
**Steps:**
1. Create/play custom level
2. Complete it
3. Check victory overlay

**Expected:**
- [ ] Victory shows "Done" instead of "Next Level"
- [ ] **NO AD appears**
- [ ] Returns to grid correctly

---

## Test 13: Performance Check
**Goal:** Verify app is faster without ads

### Steps:
1. Time how long it takes to complete 5 levels in sequence
2. Note any lag or delays

### Expected Results:
- [ ] No delays between levels
- [ ] No "Loading ad..." states
- [ ] Instant transitions
- [ ] Estimated time saved: 30-120 seconds compared to old version

---

## Test 14: UI Verification
**Goal:** Ensure no ad-related UI artifacts

### Checklist:
- [ ] No "Loading ad" indicators anywhere
- [ ] No blank spaces where ads used to be
- [ ] All buttons work as expected
- [ ] No console errors about ads
- [ ] No memory leaks from AdCoordinator

---

## Regression Testing
**Goal:** Verify nothing else broke

### Features to Check:
- [ ] Undo/Redo works
- [ ] Notes work correctly
- [ ] Hints work (if enabled)
- [ ] Multi-select works
- [ ] Color picker works
- [ ] Settings save correctly
- [ ] Timer counts correctly
- [ ] Mistake detection works
- [ ] All variant rules work (Sandwich, Killer, etc.)
- [ ] Game saves and loads correctly

---

## Final Verification

### Summary Checklist:
- [ ] ✅ No ads when unlocking levels
- [ ] ✅ No ads when starting levels
- [ ] ✅ No ads when continuing levels
- [ ] ✅ No ads when restarting levels
- [ ] ✅ No ads after completing levels
- [ ] ✅ Sequential unlocking works correctly
- [ ] ✅ Locked levels show helpful messages
- [ ] ✅ Level 1 always unlocked
- [ ] ✅ Section gate (251+) still works
- [ ] ✅ Remove Ads IAP still works
- [ ] ✅ Debug mode still works
- [ ] ✅ No regressions in gameplay

---

## Known Issues to Watch For

### Potential Problems:
1. **AdCoordinator still referenced** - Views still have `@ObservedObject var adCoordinator` but don't call its methods
   - ✅ This is fine, infrastructure is preserved for future use
   
2. **Remove Ads IAP meaningless** - No ads exist, so IAP does nothing
   - ⚠️ Consider removing from store OR repurposing as "Support Developer"
   
3. **Ad network still initialized** - Google Mobile Ads SDK still loads
   - ⚠️ Consider removing SDK if not using rewarded ads either

---

## Success Criteria

### Must Pass All:
- ✅ Zero ads shown during normal gameplay
- ✅ Levels unlock sequentially (no skipping)
- ✅ Smooth, fast user experience
- ✅ All existing features still work
- ✅ No crashes or errors

### App is Ready When:
- All tests pass
- No ads observed in 10+ consecutive level completions
- Sequential unlocking verified for at least 10 levels
- No console errors related to ads or unlocking

---

## Post-Testing Actions

### After Successful Testing:
1. [ ] Update App Store description (remove references to ads)
2. [ ] Update screenshots (remove any ad-related UI)
3. [ ] Consider removing/repurposing "Remove Ads" IAP
4. [ ] Update privacy policy (if ad networks removed)
5. [ ] Update app version number
6. [ ] Create release notes highlighting ad-free experience

### Release Notes Suggestion:
```
✨ Major Update - Ad-Free Experience!

• Removed all interstitial ads - play uninterrupted!
• Improved level progression - unlock by completing previous level
• Faster transitions between levels
• Smoother overall gameplay experience
• Bug fixes and performance improvements

Enjoy puzzle-solving without interruptions!
```

---

## Conclusion

If all tests pass, your app is now:
- ✅ Completely ad-free during gameplay
- ✅ Using fair sequential unlocking
- ✅ Providing the best user experience possible

**Ready for release! 🚀**
