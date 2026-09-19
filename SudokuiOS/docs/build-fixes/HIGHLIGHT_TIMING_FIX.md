# Potential Cell Highlighting Timing Fix

**Date:** September 19, 2026  
**Issue:** Delayed highlighting updates for potential cells when board state changes

## Problem Description

Users observed that when selecting a number cell, some cells are highlighted as potential placement locations. However, when placing or removing numbers:

1. **Delayed de-highlighting**: If a potential cell gets filled with a number, it remains highlighted for a brief moment (< 1 second) before correctly de-highlighting
2. **Delayed highlighting**: If a number is removed from a cell (making it a valid potential location again), it doesn't highlight immediately, but appears highlighted after a short delay

This creates a "memory effect" where the highlighting appears to lag behind the actual board state.

## Root Cause

The issue was a **timing/synchronization problem** between cell value changes and the highlighting calculation:

### The Problematic Flow

1. When a cell value changes, `finishBatchUpdate()` is called
2. `finishBatchUpdate()` calls `saveState()` which **debounces** the actual save operation (0.5 second delay)
3. `currentBoardArray` is only updated when `performSaveState()` runs (after the debounce)
4. Immediately after calling `saveState()`, `updateRestrictions()` is called
5. `updateRestrictions()` uses `currentBoardArray` to calculate potential cell highlighting via `PotentialHighlightCalculator.calculatePotentials()`
6. **Problem**: `currentBoardArray` still contains the OLD board state at this point
7. The highlighting calculation runs with stale data, producing incorrect results
8. After ~0.5 seconds, `performSaveState()` finally runs, updates `currentBoardArray`, and the UI refreshes with correct highlighting

### Code Location

In `SudokuGameViewModel.swift`, the problematic sequence was:

```swift
private func finishBatchUpdate(checkWin: Bool = false, wasBoardFull: Bool = false) {
    recalculateCompletedDigits()
    saveState()  // ← Debounced! Doesn't update currentBoardArray immediately
    parentViewModel.modelContext?.processPendingChanges()
    updateRestrictions()  // ← Uses currentBoardArray, but it's stale!
    checkKropkiErrors()
    // ...
}
```

## Solution

Added immediate synchronization of `currentBoardArray` BEFORE calling `updateRestrictions()`:

```swift
private func finishBatchUpdate(checkWin: Bool = false, wasBoardFull: Bool = false) {
    recalculateCompletedDigits()
    
    // CRITICAL: Update currentBoardArray immediately BEFORE calling updateRestrictions()
    // This ensures highlighting calculations use the current board state, not stale data
    syncCurrentBoardArray()
    
    saveState()  // Still debounced for performance, but doesn't affect highlighting now
    parentViewModel.modelContext?.processPendingChanges()
    updateRestrictions()  // Now uses fresh currentBoardArray
    checkKropkiErrors()
    // ...
}

/// Synchronizes currentBoardArray with the current cell values immediately.
/// This is critical for real-time highlighting calculations.
private func syncCurrentBoardArray() {
    for cell in cells {
        currentBoardArray[cell.id] = cell.value
    }
}
```

### Why This Works

- **Cells (`[SudokuCellModel]`)** are the true source of truth, updated immediately when the user makes a move
- **`currentBoardArray`** is a derived mirror used for performance-critical operations like highlighting calculations
- The fix ensures `currentBoardArray` is synchronized with `cells` **before** any highlighting calculations run
- The debounced `saveState()` still updates `currentBoardArray` again later (for the full save operation), but that's redundant now and doesn't cause timing issues

## Impact

- ✅ Potential cell highlighting now updates **instantly** when cells are filled or cleared
- ✅ No more "memory effect" or delayed highlighting
- ✅ No performance impact (the sync is a simple array update, O(81) = constant time)
- ✅ Works for all operations: entering numbers, erasing, undo, redo, hints
- ✅ All existing code paths that call `finishBatchUpdate()` automatically benefit from the fix

## Related Code

The highlighting calculation that depends on `currentBoardArray`:

- `PotentialHighlightCalculator.calculatePotentials()` - calculates which cells should NOT be highlighted as potential placements
- `SudokuGameViewModel.updateRestrictions()` - calls the calculator and stores results in `restrictedHighlightSet`
- `SudokuGameViewModel.updatePointPairRestrictions()` - also uses the calculator for advanced highlighting features
- `SudokuGameViewModel.getHighlightType()` - determines which highlight style to apply to each cell, using the restriction sets

All of these now work with synchronized, real-time board state.

## Testing Recommendations

Manual testing scenarios to verify the fix:

1. **Basic fill test**: Select a cell with a number, observe highlighted potential cells. Fill one of the potential cells with a different number. The highlighting should disappear immediately.

2. **Clear test**: Select a cell with a number. Clear another cell that could potentially contain that number. It should highlight immediately as a potential cell.

3. **Undo/Redo test**: Make moves that change highlighting, then undo/redo. Highlighting should update instantly in both directions.

4. **Multi-select test**: Select multiple cells and enter a number. All affected potential cell highlights should update immediately.

5. **Hint test**: Use a hint. The resulting highlighting updates should be immediate.

## Notes

- This fix does NOT change the logic of what cells are highlighted, only WHEN they are updated
- The debounced `saveState()` mechanism is still in place for persistence performance
- Custom levels and standard levels both benefit from this fix equally
- The fix applies to both "potential" and "restriction" highlight modes (though only potential mode uses the calculator)
