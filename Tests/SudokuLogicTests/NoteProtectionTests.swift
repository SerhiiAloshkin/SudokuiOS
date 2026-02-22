import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
class NoteProtectionTests: XCTestCase {
    
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
        viewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
    }

    func testNoteModeDoesNotOverwriteUserValue() {
        let index = 0
        // Setup: User enters a value
        viewModel.selectCell(index)
        viewModel.enterNumber(5)
        XCTAssertEqual(viewModel.cells[index].value, 5)
        
        // Action: Enable Note Mode and try to enter a note
        viewModel.isNoteMode = true
        viewModel.didTapNumber(1)
        
        // Assert: Value remains, Note is NOT added (or effectively ignored/hidden)
        XCTAssertEqual(viewModel.cells[index].value, 5, "Value should not be cleared")
        XCTAssertFalse(viewModel.cells[index].notes.contains(1), "Note should not be added to a filled cell")
    }
    
    func testNoteModeDoesNotOverwriteClue() {
        // Find a clue cell (usually level 1 has clues)
        guard let clueIndex = viewModel.cells.firstIndex(where: { $0.isClue }) else {
            XCTFail("Level 1 should have clues")
            return
        }
        let clueValue = viewModel.cells[clueIndex].value
        
        // Action: Select and try to add note
        viewModel.selectCell(clueIndex)
        viewModel.isNoteMode = true
        viewModel.didTapNumber(9)
        
        // Assert
        XCTAssertEqual(viewModel.cells[clueIndex].value, clueValue, "Clue should persist")
        XCTAssertFalse(viewModel.cells[clueIndex].notes.contains(9), "Note should not be added to clue cell")
    }
}
