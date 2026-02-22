import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
class SudokuGameViewModelTests: XCTestCase {
    
    var viewModel: SudokuGameViewModel!
    var levelViewModel: LevelViewModel!
    var container: ModelContainer!
    
    override func setUpWithError() throws {
        // Setup in-memory SwiftData container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, MoveHistory.self, configurations: config)
        
        levelViewModel = LevelViewModel(modelContext: container.mainContext)
        // Ensure levels are loaded (might need wait or manual trigger depending on logic)
        // LevelViewModel init loads JSON synchronously.
        
        // Initialize Game VM for Level 1
        viewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        viewModel.setSettings(AppSettings()) // Default settings
    }

    func testInitialization() {
        XCTAssertEqual(viewModel.levelID, 1)
        XCTAssertFalse(viewModel.cells.isEmpty)
        XCTAssertEqual(viewModel.cells.count, 81)
        // Level 1 logic implies some cells allow input
        XCTAssertFalse(viewModel.isSolved)
    }
    
    func testInput_EnterNumber() {
        // Find an empty cell (non-clue)
        guard let index = viewModel.cells.firstIndex(where: { !$0.isClue && $0.value == 0 }) else {
            XCTFail("No empty cell found in Level 1")
            return
        }
        
        // Select logic
        viewModel.selectCell(index)
        
        // Enter number 5
        viewModel.didTapNumber(5)
        
        XCTAssertEqual(viewModel.cells[index].value, 5)
        
        // Toggle (remove)
        viewModel.didTapNumber(5)
        XCTAssertEqual(viewModel.cells[index].value, 0)
    }
    
    func testInput_ToggleNote() {
        guard let index = viewModel.cells.firstIndex(where: { !$0.isClue && $0.value == 0 }) else { return }
        
        viewModel.selectCell(index)
        viewModel.toggleNoteMode()
        XCTAssertTrue(viewModel.isNoteMode)
        
        // Add Note 3
        viewModel.didTapNumber(3)
        XCTAssertTrue(viewModel.cells[index].notes.contains(3))
        
        // Remove Note 3
        viewModel.didTapNumber(3)
        XCTAssertFalse(viewModel.cells[index].notes.contains(3))
    }
    
    func testSandwichHelper_DefaultSelection() {
        // Setup a clue selection
        // Mock a clue logic: Row 0 has some sum.
        // On selection, it should auto-fill markedCombinations
        viewModel.selectClue(index: 0, isRow: true, sum: 10)
        
        let id = "Row-0"
        XCTAssertNotNil(viewModel.markedCombinations[id])
        XCTAssertFalse(viewModel.markedCombinations[id]!.isEmpty, "Should auto-select combinations")
    }
    
    func testPersistence_InstantSave() {
        // Modify a cell
        guard let index = viewModel.cells.firstIndex(where: { !$0.isClue }) else { return }
        viewModel.selectCell(index)
        viewModel.didTapNumber(7)
        
        // Check if saved to UserLevelProgress
        // We need to fetch from context
        let descriptor = FetchDescriptor<UserLevelProgress>(predicate: #Predicate { $0.levelID == 1 })
        let progress = try? container.mainContext.fetch(descriptor).first
        
        XCTAssertNotNil(progress)
        XCTAssertEqual(progress?.currentUserBoard, viewModel.currentBoard)
    }
}
