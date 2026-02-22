import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
class ToggleTests: XCTestCase {
    
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

    func testCellSelectionToggle() {
        let index = 0
        
        // 1. Initial State: No selection
        XCTAssertNil(viewModel.selectedCellIndex)
        
        // 2. Select Cell 0
        viewModel.selectCell(index)
        XCTAssertEqual(viewModel.selectedCellIndex, index)
        XCTAssertTrue(viewModel.selectedIndices.contains(index))
        
        // 3. Toggle Off (Tap same cell)
        viewModel.selectCell(index)
        XCTAssertNil(viewModel.selectedCellIndex, "Tapping the same cell should deselect it")
        XCTAssertTrue(viewModel.selectedIndices.isEmpty, "Selection set should be empty")
    }
    
    func testNumberPadToggle() {
        let digit = 9
        
        // 1. Ensure no cell selected
        viewModel.selectedCellIndex = nil
        viewModel.selectedIndices = []
        XCTAssertNil(viewModel.explicitHighlightedDigit)
        
        // 2. Tap '9'
        viewModel.didTapNumber(digit) 
        
        // 3. Verify '9' is explicitly highlighted
        XCTAssertEqual(viewModel.explicitHighlightedDigit, digit)
        XCTAssertEqual(viewModel.selectedDigit, digit, "selectedDigit should reflect the explicit highlight")
        
        // 4. Tap '9' again -> Toggle Off
        viewModel.didTapNumber(digit)
        XCTAssertNil(viewModel.explicitHighlightedDigit, "Tapping same number should toggle highlight off")
        XCTAssertNil(viewModel.selectedDigit)
    }
    
    func testExplicitHighlightOverrides() {
        let digit = 5
        let index = 10
        
        // 1. Set explicit highlight
        viewModel.didTapNumber(digit)
        XCTAssertEqual(viewModel.explicitHighlightedDigit, digit)
        
        // 2. Select a cell -> Should clear explicit highlight
        viewModel.selectCell(index)
        
        XCTAssertNil(viewModel.explicitHighlightedDigit, "Selecting a cell should clear explicit number highlight")
        XCTAssertEqual(viewModel.selectedCellIndex, index)
    }
}
