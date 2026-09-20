# Ad Removal - Complete Cleanup Plan

## Overview

The game is now **100% ad-free**. All legacy ad code must be removed.

---

## Files Found with Ad Code

### 1. AdCoordinator.swift (207 lines) - **DELETE ENTIRE FILE**
- Google AdMob integration
- Interstitial ad loading
- Rewarded ad loading
- Ad cooldown logic
- **Action:** Delete completely

### 2. LevelViewModel.swift - **REMOVE AD UNLOCK LOGIC**
- `hasRemovedAds` property (lines 244-247)
- `unlockLevelViaAd()` function (lines 846-870)
- `isAdUnlocked` checks in `recalculateLocks()` (we JUST added this for Bug #1!)
- **Action:** Remove ad-unlock system entirely

### 3. LevelPreviewModal.swift - **REMOVE AD COORDINATOR REFERENCE**
- `@ObservedObject var adCoordinator: AdCoordinator` (line 6)
- **Action:** Remove this parameter

### 4. UserLevelProgress Model - **REMOVE isAdUnlocked FIELD**
- The SwiftData model likely has `isAdUnlocked: Bool` field
- **Action:** Need to find and remove

### 5. SudokuLevel struct - **REMOVE isAdUnlocked FIELD**
- Line 11 has `var isAdUnlocked: Bool = false`
- **Action:** Remove this field

---

## Strategy: What to Keep vs. Remove

### ✅ KEEP (These are NOT ads)
- `hasRemovedAds` / `isAdsRemoved` UserDefaults flag → **Rename to "isPremiumUser" or "hasFullAccess"**
  - This unlocks all levels immediately
  - It's an IAP (In-App Purchase) feature, not an ad
  - Used in unlock logic (line 765 in `recalculateLocks`)

### ❌ REMOVE (Pure ad legacy)
- `AdCoordinator.swift` - entire file
- `unlockLevelViaAd()` - function that unlocks single level via ad
- `isAdUnlocked` - per-level flag for ad-based unlocks
- References to `adCoordinator` in UI

---

## Phased Removal Plan

### Phase A: Remove Ad Unlock System (Per-Level Ads)
**Impact:** Medium - Just added Bug #1 fix that uses this!

**What to remove:**
1. `unlockLevelViaAd()` function in `LevelViewModel`
2. `isAdUnlocked` field in `SudokuLevel` struct
3. `isAdUnlocked` field in `UserLevelProgress` model
4. The Bug #1 fix we just added (check for `isAdUnlocked` in `recalculateLocks`)

**Rationale:** 
- No ads = no way to unlock individual levels via ads
- The sequential unlock system is the ONLY way now
- Premium IAP still unlocks everything instantly

### Phase B: Remove Ad Infrastructure
**Impact:** High - Core ad system

**What to remove:**
1. `AdCoordinator.swift` - entire file (207 lines)
2. `@ObservedObject var adCoordinator` references in UI
3. Google AdMob SDK imports (if any)

### Phase C: Rename IAP Flag
**Impact:** Low - Clarity improvement

**What to rename:**
- `"isAdsRemoved"` → `"isPremiumUser"` or `"hasUnlockedAllLevels"`
- Makes it clear it's NOT about removing ads, but about premium access

---

## Detailed Changes

### Change 1: Remove isAdUnlocked from SudokuLevel

**File:** `LevelViewModel.swift` (top struct definition)

**Current:**
```swift
struct SudokuLevel: Identifiable, Codable, Equatable {
    let id: Int
    var customTitle: String?
    var customUUID: String?
    var isLocked: Bool
    var isAdUnlocked: Bool = false // ← REMOVE THIS
    var isUnlocked: Bool = false
    // ...
}
```

**Fixed:**
```swift
struct SudokuLevel: Identifiable, Codable, Equatable {
    let id: Int
    var customTitle: String?
    var customUUID: String?
    var isLocked: Bool
    var isUnlocked: Bool = false  // Keep this (sticky unlock)
    // ...
}
```

---

### Change 2: Remove isAdUnlocked check from recalculateLocks (UNDO Bug #1 Fix)

**File:** `LevelViewModel.swift` lines ~769

**Current (we just added this):**
```swift
// 4. Ad-unlocked levels stay unlocked (FIX: Phase 1 Bug #1)
if levels[i].isAdUnlocked {
    levels[i].isLocked = false
    continue
}
```

**Fixed (remove it):**
```swift
// (Delete these 5 lines entirely)
```

**Note:** Bug #1 is actually a non-issue now! Without ads, there's no `unlockLevelViaAd()` to call.

---

### Change 3: Remove unlockLevelViaAd function

**File:** `LevelViewModel.swift` lines 846-870

**Delete this entire function:**
```swift
// MARK: - Ad Unlock
func unlockLevelViaAd(_ id: Int) {
    // ... (delete entire function)
}
```

---

### Change 4: Remove isAdUnlocked from UserLevelProgress

**File:** Need to find `UserLevelProgress.swift` or model definition

**Search for and remove:**
```swift
var isAdUnlocked: Bool = false
```

---

### Change 5: Remove isAdUnlocked assignment in loadLevels()

**File:** `LevelViewModel.swift` line 327

**Current:**
```swift
localLevels[i].isAdUnlocked = progress.isAdUnlocked
```

**Fixed:**
```swift
// (Delete this line)
```

---

### Change 6: Remove AdCoordinator.swift

**Action:** Delete entire file

---

### Change 7: Remove adCoordinator from LevelPreviewModal

**File:** `LevelPreviewModal.swift` line 6

**Current:**
```swift
@ObservedObject var adCoordinator: AdCoordinator // Ad Manager
```

**Fixed:**
```swift
// (Delete this line)
```

**Also update any call sites** that pass `adCoordinator` to this view.

---

### Change 8 (Optional): Rename IAP flag for clarity

**Files:** Everywhere `"isAdsRemoved"` appears

**Current:**
```swift
UserDefaults.standard.bool(forKey: "isAdsRemoved")
```

**Better:**
```swift
UserDefaults.standard.bool(forKey: "isPremiumUser")
```

**Rationale:** There are no ads to remove! This flag means "has purchased premium IAP that unlocks all levels"

---

## Testing After Removal

### Verify These Still Work

1. **Sequential unlocking**
   - Solve level N → level N+1 unlocks ✅
   - Level 250→251 transition requires all 1-250 solved ✅

2. **Premium IAP unlocking**
   - Set `isPremiumUser` = true → all levels unlock ✅

3. **No ad-related UI**
   - No "Watch Ad to Unlock" buttons ✅
   - No ad coordinator references ✅

### Verify These Are Gone

- [ ] No `unlockLevelViaAd()` calls anywhere
- [ ] No `isAdUnlocked` references
- [ ] No `AdCoordinator` imports
- [ ] No Google AdMob SDK code

---

## Estimated Impact

| Component | Lines Removed | Complexity |
|-----------|--------------|------------|
| `AdCoordinator.swift` | 207 | Low (delete file) |
| `unlockLevelViaAd()` | ~30 | Low (delete function) |
| `isAdUnlocked` fields | ~10 | Medium (model changes) |
| UI references | ~5 | Low (delete params) |
| **Total** | **~252 lines** | **Medium** |

---

## Migration Note

**Existing users with ad-unlocked levels:**

If any users currently have levels marked `isAdUnlocked = true`, those will be lost when we remove the field. 

**Options:**
1. **Ignore it** - Users will just re-unlock via sequential or IAP
2. **Migration script** - Convert `isAdUnlocked=true` → `isUnlocked=true` (sticky) before removal
3. **Grace period** - Mark all ad-unlocked levels as permanently unlocked

**Recommendation:** Option 1 (ignore) - simplest, minimal user impact since ad unlocks were temporary anyway.

---

## Execution Order

1. ✅ Search for all `isAdUnlocked` references
2. ✅ Remove from `SudokuLevel` struct
3. ✅ Remove from `UserLevelProgress` model
4. ✅ Remove from `loadLevels()` assignments
5. ✅ Remove from `recalculateLocks()` (undo Bug #1 fix)
6. ✅ Delete `unlockLevelViaAd()` function
7. ✅ Delete `AdCoordinator.swift` file
8. ✅ Remove `adCoordinator` from UI
9. ✅ (Optional) Rename `isAdsRemoved` → `isPremiumUser`
10. ✅ Build & test

---

**Ready to execute?** This is a significant cleanup (~250 lines removed).

Should I proceed with the ad removal, or do you want to review this plan first?
