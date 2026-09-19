import Foundation
import Combine

/// Manages move history for undo/redo functionality
/// Extracts move history logic from SudokuGameViewModel
@MainActor
final class MoveHistoryManager: ObservableObject {
    
    // MARK: - Move Structure
    
    struct Move {
        let index: Int
        let previousValue: Int
        let newValue: Int
        let previousNotes: Set<Int>
        let newNotes: Set<Int>
        let previousColor: Int?
        let newColor: Int?
        let previousCross: Bool
        let newCross: Bool
        let timestamp: Date
        
        init(
            index: Int,
            previousValue: Int,
            newValue: Int,
            previousNotes: Set<Int> = [],
            newNotes: Set<Int> = [],
            previousColor: Int? = nil,
            newColor: Int? = nil,
            previousCross: Bool = false,
            newCross: Bool = false
        ) {
            self.index = index
            self.previousValue = previousValue
            self.newValue = newValue
            self.previousNotes = previousNotes
            self.newNotes = newNotes
            self.previousColor = previousColor
            self.newColor = newColor
            self.previousCross = previousCross
            self.newCross = newCross
            self.timestamp = Date()
        }
    }
    
    // MARK: - State
    
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    
    private var undoStack: [Move] = []
    private var redoStack: [Move] = []
    
    private let maxHistorySize = 100 // Prevent memory bloat
    
    // MARK: - Recording Moves
    
    func recordMove(_ move: Move) {
        undoStack.append(move)
        redoStack.removeAll() // Clear redo stack on new move
        
        // Limit history size
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
        
        updateCanUndoRedo()
    }
    
    func recordValueChange(
        index: Int,
        from previousValue: Int,
        to newValue: Int,
        previousNotes: Set<Int> = [],
        newNotes: Set<Int> = []
    ) {
        let move = Move(
            index: index,
            previousValue: previousValue,
            newValue: newValue,
            previousNotes: previousNotes,
            newNotes: newNotes
        )
        recordMove(move)
    }
    
    func recordNoteChange(
        index: Int,
        from previousNotes: Set<Int>,
        to newNotes: Set<Int>
    ) {
        let move = Move(
            index: index,
            previousValue: 0, // Notes don't change value
            newValue: 0,
            previousNotes: previousNotes,
            newNotes: newNotes
        )
        recordMove(move)
    }
    
    func recordColorChange(
        index: Int,
        from previousColor: Int?,
        to newColor: Int?
    ) {
        let move = Move(
            index: index,
            previousValue: 0,
            newValue: 0,
            previousColor: previousColor,
            newColor: newColor
        )
        recordMove(move)
    }
    
    // MARK: - Undo/Redo
    
    func undo() -> Move? {
        guard !undoStack.isEmpty else { return nil }
        
        let move = undoStack.removeLast()
        redoStack.append(move)
        
        updateCanUndoRedo()
        return move
    }
    
    func redo() -> Move? {
        guard !redoStack.isEmpty else { return nil }
        
        let move = redoStack.removeLast()
        undoStack.append(move)
        
        updateCanUndoRedo()
        return move
    }
    
    // MARK: - State Management
    
    private func updateCanUndoRedo() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateCanUndoRedo()
    }
    
    // MARK: - Stats
    
    var moveCount: Int {
        undoStack.count
    }
    
    var lastMove: Move? {
        undoStack.last
    }
    
    // MARK: - Batch Operations
    
    func recordBatchMoves(_ moves: [Move]) {
        undoStack.append(contentsOf: moves)
        redoStack.removeAll()
        
        // Trim if needed
        if undoStack.count > maxHistorySize {
            let excess = undoStack.count - maxHistorySize
            undoStack.removeFirst(excess)
        }
        
        updateCanUndoRedo()
    }
}
