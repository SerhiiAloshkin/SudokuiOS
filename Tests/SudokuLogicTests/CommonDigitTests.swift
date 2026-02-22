import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
class CommonDigitTests: XCTestCase {
    
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

    func testCommonDigitHighlight() {
        // Setup: Set Cell 0 and Cell 1 to value '5'
        viewModel.selectCell(0)
        viewModel.enterNumber(5)
        viewModel.selectCell(1)
        viewModel.enterNumber(5)
        
        // 1. Initial: Single Selection does NOT trigger global explicit highlight (it uses standard view logic)
        // explicitHighlightedDigit should be NIL (unless we tap number pad)
        XCTAssertNil(viewModel.explicitHighlightedDigit)
        
        // 2. Multi-Select Both (Drag or Multi-mode)
        viewModel.dragSelect(0, isStart: true)
        viewModel.dragSelect(1, isStart: false)
        
        // Assert: Common Digit '5' should be explicitly highlighted
        XCTAssertEqual(viewModel.explicitHighlightedDigit, 5)
        
        // 3. Add a Mixed Value (Cell 2 = '3')
        viewModel.selectCell(2)
        viewModel.enterNumber(3)
        // Select 0, 1, 2
        viewModel.dragSelect(0, isStart: true)
        viewModel.dragSelect(1, isStart: false)
        viewModel.dragSelect(2, isStart: false)
        
        // Assert: Mixed values -> No Highlight
        XCTAssertNil(viewModel.explicitHighlightedDigit)
        
        // 4. Add Empty Cell
        // Select 0, 1 and Empty Cell 3
        viewModel.dragSelect(0, isStart: true)
        viewModel.dragSelect(1, isStart: false)
        viewModel.dragSelect(3, isStart: false) // Cell 3 is empty
        
        // Assert: Empty included -> No Highlight
        XCTAssertNil(viewModel.explicitHighlightedDigit)
    }
}
