#!/bin/bash

# Phase 1 Cleanup Script
# Deletes 6 confirmed dead manager files
# Run this from your project root directory

echo "================================================"
echo "Phase 1: Dead Code Cleanup"
echo "Deleting 6 unused manager files (~1,067 lines)"
echo "================================================"
echo ""

# Array of files to delete
FILES_TO_DELETE=(
    "GameStateManager.swift"
    "TimerManager.swift"
    "HintSystemManager.swift"
    "GamePersistenceManager.swift"
    "MoveHistoryManager.swift"
    "OptimizedPotentialHighlightCalculator.swift"
)

# Counter for successful deletions
DELETED=0
MISSING=0

# Delete each file
for FILE in "${FILES_TO_DELETE[@]}"; do
    # Try to find the file in common locations
    FOUND=false
    
    for DIR in "." "SudokuiOS" "SudokuiOS/Managers" "SudokuiOS/ViewModels" "SudokuiOS/Core"; do
        if [ -f "$DIR/$FILE" ]; then
            echo "✅ Deleting: $DIR/$FILE"
            rm "$DIR/$FILE"
            DELETED=$((DELETED + 1))
            FOUND=true
            break
        fi
    done
    
    if [ "$FOUND" = false ]; then
        echo "⚠️  Not found: $FILE (may already be deleted)"
        MISSING=$((MISSING + 1))
    fi
done

echo ""
echo "================================================"
echo "Summary:"
echo "  Deleted: $DELETED files"
echo "  Not found: $MISSING files"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Open your Xcode project"
echo "2. Remove these file references from Xcode if they still appear (right-click > Delete > Remove Reference)"
echo "3. Build the project to verify it still compiles"
echo "4. Run tests if available"
echo "5. Commit the changes: git commit -m 'Phase 1 cleanup: Remove dead manager files'"
echo ""
echo "See PHASE1_CLEANUP.md for detailed documentation."
