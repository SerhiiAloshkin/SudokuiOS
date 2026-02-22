import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
class StateTests: XCTestCase {
    
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

    func testStatePriorityAndReset() {
        let digit = 1
        let cellIndex = 0
        
        // 1. Initial State: Neutral
        XCTAssertNil(viewModel.explicitHighlightedDigit)
        XCTAssertNil(viewModel.selectedCellIndex)
        XCTAssertNil(viewModel.selectedDigit)
        
        // 2. Global Highlight (Tap 1)
        viewModel.didTapNumber(digit)
        XCTAssertEqual(viewModel.explicitHighlightedDigit, digit)
        XCTAssertEqual(viewModel.selectedDigit, digit)
        XCTAssertNil(viewModel.selectedCellIndex)
        
        // 3. Select Cell -> Should override and clear Global Highlight
        viewModel.selectCell(cellIndex)
        XCTAssertEqual(viewModel.selectedCellIndex, cellIndex)
        XCTAssertNil(viewModel.explicitHighlightedDigit, "Implicit highlight should be cleared")
        XCTAssertNil(viewModel.selectedDigit, "selectedDigit should be nil when cell selected (Note Highlight disabled)")
        
        // 4. Deselect Cell -> Should return to Neutral (NOT restore global)
        viewModel.selectCell(cellIndex) // Toggle off
        XCTAssertNil(viewModel.selectedCellIndex)
        XCTAssertNil(viewModel.explicitHighlightedDigit)
        XCTAssertNil(viewModel.selectedDigit)
    }
    
    func testDeselectingCellEnsuresNeutral() {
        // Setup: Select Cell
        viewModel.selectCell(0)
        XCTAssertNotNil(viewModel.selectedCellIndex)
        
        // Action: Deselect
        viewModel.selectCell(0)
        
        // Assert: Neutral
        XCTAssertNil(viewModel.selectedCellIndex)
        XCTAssertNil(viewModel.explicitHighlightedDigit)
    }
}
