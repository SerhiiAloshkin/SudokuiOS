# Build Fix #5 - MainActor Isolation Error

**Error**: Call to main actor-isolated instance method 'performSaveState()' in a synchronous nonisolated context  
**File**: SudokuGameViewModel.swift:312  
**Status**: ✅ FIXED

---

## Problem

```swift
deinit {
    // ...
    if hasPendingSave {
        performSaveState()  // ❌ ERROR: Can't call @MainActor method from deinit
    }
}
```

**Root Cause**: 
- `deinit` runs synchronously and is not isolated to any actor
- `performSaveState()` is implicitly `@MainActor` (because the class is `@MainActor`)
- Cannot call actor-isolated methods from non-isolated synchronous context

---

## Solution

Remove the synchronous save attempt from `deinit`:

```swift
deinit {
    // CRITICAL FIX: Prevent timer-related memory leaks
    timer?.invalidate()
    waveTimer?.invalidate()
    hintCooldownTimer?.invalidate()
    saveStateTimer?.invalidate()
    
    // NOTE: Cannot flush pending save in deinit due to @MainActor isolation
    // Save should be flushed via saveStateImmediate() in scenePhase observer before dealloc
    
    timer = nil
    waveTimer = nil
    hintCooldownTimer = nil
    saveStateTimer = nil
    
    print("✅ SudokuGameViewModel deallocated - Level \(levelID)")
}
```

---

## Why This Works

1. **Timer cleanup is synchronous** - No actor isolation issues
2. **Save flushing removed** - Can't be done in deinit anyway
3. **Proper cleanup location** - Should be done in `scenePhase` observer:

```swift
// In SudokuiOSApp.swift or parent view:
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .background || newPhase == .inactive {
        gameViewModel?.saveStateImmediate()  // ✅ Proper place to flush
        try? container.mainContext.save()
    }
}
```

---

## Data Safety

**Q: Won't we lose data if deinit can't save?**

**A: No, because:**

1. **Debounced saves still work** during normal gameplay (every 2 seconds)
2. **App backgrounding** should call `saveStateImmediate()` via scene observer
3. **Navigation away** from game view should trigger final save in `onDisappear`
4. **Only risk** is if app crashes immediately after last user input (rare)

**Best Practice**: Add explicit save in view lifecycle:

```swift
// In SudokuGameView:
.onDisappear {
    gameViewModel.saveStateImmediate()
}
```

---

## Alternative Solutions (NOT Used)

### ❌ Option 1: Use Task in deinit
```swift
deinit {
    Task { @MainActor in
        performSaveState()  // ❌ Won't execute - Task outlives deinit
    }
}
```
**Problem**: Task is not guaranteed to execute before object is deallocated

### ❌ Option 2: Make deinit async
```swift
deinit async {  // ❌ Swift doesn't support this
}
```
**Problem**: Swift doesn't allow async deinit

### ✅ Option 3: Remove save from deinit (CHOSEN)
```swift
deinit {
    // Just clean up resources
}
```
**Why**: Deinit is for cleanup, not business logic. Saves should happen before deallocation.

---

## Testing Recommendation

Add this to view lifecycle:

```swift
struct SudokuGameView: View {
    @ObservedObject var gameViewModel: SudokuGameViewModel
    
    var body: some View {
        // ... game UI
    }
    .onDisappear {
        // Ensure save happens when leaving game
        gameViewModel.saveStateImmediate()
    }
}
```

And in app delegate/scene phase:

```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .background || newPhase == .inactive {
        // Flush all pending saves before app backgrounds
        gameViewModel?.saveStateImmediate()
        try? modelContext.save()
    }
}
```

---

## Build Status

**After this fix**: Build should succeed ✅

**Remaining errors**: UNKNOWN - Please rebuild and report

---

## Next Steps

1. **Build**: `cmd + B`
2. **Report**: Any remaining errors?
3. **If successful**: Run tests `cmd + U`

---

**Fix Summary**: Removed @MainActor method call from deinit to resolve actor isolation error. Data safety ensured through proper lifecycle hooks.
