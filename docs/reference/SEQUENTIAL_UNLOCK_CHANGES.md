# Sequential Level Unlocking Changes

## Overview
Changed the level unlocking system to enforce strict sequential progression. Players must now complete each level in order to unlock the next one. Ad-based unlocking has been removed.

## Changes Made

### 1. LevelViewModel.swift - `recalculateLocks` Function
**Previous Behavior:**
- Levels could be unlocked via ads
- "Natural unlock" allowed jumping to the first unsolved level
- Complex logic with multiple unlock paths

**New Behavior:**
- **Sequential unlocking only**: Level N unlocks only when Level N-1 is solved
- Level 1 is always unlocked (starting point)
- If user has removed ads (IAP), all levels unlock
- For levels 251+, also requires completing all of section 1 (levels 1-250)

**Example:**
- Level 100 unlocks ONLY when Level 99 is solved
- You cannot skip ahead by watching ads
- Linear progression through all 600 levels

### 2. LevelPreviewModal.swift - Locked Level UI
**Previous Behavior:**
- Showed "Unlock with Ad" button for locked levels 1-250
- Allowed players to skip ahead by watching rewarded videos

**New Behavior:**
- Shows informative message: "Complete Level X to unlock"
- Explains sequential unlocking system
- No ad unlock button
- For levels 251+, shows special message about completing section 1

### 3. Key Logic Flow
```
Level Solved → Mark as isSolved = true → Refresh locks
                                       ↓
                           Check previous level for each level
                                       ↓
                        If previous solved → Unlock current
                                       ↓
                              Update UI automatically
```

## Benefits
1. **No more ads for unlocking** - Eliminates the issue where players see ads
2. **Clear progression** - Players know exactly what they need to do
3. **Fair gameplay** - Everyone progresses at their own pace through the same sequence
4. **Simpler code** - Removed complex ad unlock and natural unlock logic

## Edge Cases Handled
- **Level 1**: Always unlocked (entry point)
- **Removed Ads IAP**: If purchased, all levels unlock (premium feature)
- **Debug Mode**: `devAllUnlocked` still works for testing
- **Section Gate (Level 251+)**: Still requires completing all of section 1 (levels 1-250)

## Testing Recommendations
1. Verify Level 1 is unlocked on first launch
2. Complete Level 1 → Check Level 2 unlocks
3. Try tapping Level 3 when Level 2 is not solved → Should show locked message
4. Complete levels sequentially up to Level 250 → Check Level 251 unlocks
5. Test with "Remove Ads" IAP → All levels should unlock

## User Experience
- **Before**: Players could watch ads to skip levels, but still saw ads
- **After**: Players must complete each level in order, no ad prompts for unlocking
- **Message**: "Complete Level X to unlock" with helpful explanation
