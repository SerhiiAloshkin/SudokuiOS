import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
class NoteHighlightingTests: XCTestCase {
    
    var viewModel: SudokuGameViewModel!
    var levelViewModel: LevelViewModel!
    var container: ModelContainer!
    
    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, MoveHistory.self, configurations: config)
        levelViewModel = LevelViewModel(modelContext: container.mainContext)
        if levelViewModel.levels.isEmpty {
           levelViewModel.loadLevelsFromJSON()
        }
    }

    func testSelectedDigitComputation() {
        viewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        
        let emptyIndex = viewModel.cells.firstIndex(where: { $0.value == 0 })!
        let filledIndex = viewModel.cells.firstIndex(where: { $0.value != 0 })!
        
        // Select empty -> Nil
        viewModel.selectCell(emptyIndex)
        XCTAssertNil(viewModel.selectedDigit)
        
        // Select filled -> Value
        viewModel.selectCell(filledIndex)
        XCTAssertEqual(viewModel.selectedDigit, viewModel.cells[filledIndex].value)
    }
    
    func testNoteHighlightPruningInteraction() {
        viewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        
        // Setup:
        // Cell A (R0C0) = Empty, will receive a value later
        // Cell B (R0C1) = Empty, has Note matching A's future value
        
        // Find two empty cells in same row
        let emptyIndices = viewModel.cells.indices.filter { viewModel.cells[$0].value == 0 && !viewModel.cells[$0].isClue }
        guard let idxA = emptyIndices.first else { return }
        let row = idxA / 9
        let idxB = emptyIndices.first { $0 != idxA && ($0 / 9) == row }
        
        guard let indexA = idxA, let indexB = idxB else { return }
        
        let digit = 5
        
        // 1. Add Note '5' to Cell B
        viewModel.selectCell(indexB)
        viewModel.toggleNoteMode()
        viewModel.didTapNumber(digit)
        XCTAssertTrue(viewModel.cells[indexB].notes.contains(digit))
        
        // 2. Select Cell A (which is empty currently) -> selectedDigit is nil
        viewModel.selectCell(indexA)
        XCTAssertNil(viewModel.selectedDigit)
        
        // 3. Place '5' in Cell A
        viewModel.toggleNoteMode() // Off
        viewModel.didTapNumber(digit)
        
        // 4. Assert:
        // - Cell A is selected and has value 5, so selectedDigit == 5
        XCTAssertEqual(viewModel.selectedDigit, digit)
        
        // - Cell B should have had its note '5' pruned
        XCTAssertFalse(viewModel.cells[indexB].notes.contains(digit), "Note should be pruned")
        
        // - Therefore, Cell B should NOT highlight (View logic depends on state)
        // Since note is gone, "notes.contains(highlightedDigit)" will be false.
    }
    
    func testHighlightVisualsLogic() {
        // Since we can't test SwiftUI View body directly easily, we verify the data state
        // that drives the view logic: (value == 0 && notes.contains(selectedDigit))
        
        viewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        
        let digit = 3
        let index = viewModel.cells.firstIndex(where: { $0.value == 0 })!
        
        // Add note
        viewModel.selectCell(index)
        viewModel.toggleNoteMode()
        viewModel.didTapNumber(digit)
        
        // Select a DIFFERENT cell that has value '3'
        // Or just mock the selection if we can't find one easily (but we can set one)
        let indexWithValue = viewModel.cells.indices.first { $0 != index && $0 / 9 != index / 9 }!
        viewModel.selectCell(indexWithValue)
        viewModel.toggleNoteMode() // Off
        viewModel.didTapNumber(digit) // Set it to 3
        
        // Now selectedDigit is 3
        XCTAssertEqual(viewModel.selectedDigit, 3)
        // Target cell has note 3
        XCTAssertTrue(viewModel.cells[index].notes.contains(3))
        
        // Condition Check
        let shouldHighlight = (viewModel.cells[index].value == 0) &&
                              (viewModel.cells[index].notes.contains(viewModel.selectedDigit!))
        
        XCTAssertTrue(shouldHighlight)
    }
}
