import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
class DragSelectTests: XCTestCase {
    
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

    func testDragSelectAccumulation() {
        // 1. Initial Selection: None
        XCTAssertTrue(viewModel.selectedIndices.isEmpty)
        
        // 2. Start Drag at Index 0 (isStart: true)
        // Should clear existing (none) and select 0
        viewModel.dragSelect(0, isStart: true)
        XCTAssertEqual(viewModel.selectedIndices, [0])
        XCTAssertEqual(viewModel.selectedCellIndex, 0)
        
        // 3. Continue Drag to Index 1 (isStart: false)
        // Should ADD 1 to selection (0, 1)
        viewModel.dragSelect(1, isStart: false)
        XCTAssertTrue(viewModel.selectedIndices.contains(0))
        XCTAssertTrue(viewModel.selectedIndices.contains(1))
        XCTAssertEqual(viewModel.selectedIndices.count, 2)
        XCTAssertEqual(viewModel.selectedCellIndex, 1) // Anchor updates to latest
        
        // 4. Continue Drag to Index 2 (isStart: false)
        // Should ADD 2 to selection (0, 1, 2)
        viewModel.dragSelect(2, isStart: false)
        XCTAssertEqual(viewModel.selectedIndices.count, 3)
        XCTAssertTrue(viewModel.selectedIndices.contains(2))
    }
    
    func testNewDragClearsPrevious() {
        // Setup: Select 0, 1, 2
        viewModel.dragSelect(0, isStart: true)
        viewModel.dragSelect(1, isStart: false)
        viewModel.dragSelect(2, isStart: false)
        XCTAssertEqual(viewModel.selectedIndices.count, 3)
        
        // Action: Start NEW Drag at Index 5 (isStart: true)
        // Should CLEAR 0, 1, 2 and select ONLY 5
        viewModel.dragSelect(5, isStart: true)
        
        // Assert
        XCTAssertEqual(viewModel.selectedIndices.count, 1)
        XCTAssertTrue(viewModel.selectedIndices.contains(5))
        XCTAssertEqual(viewModel.selectedCellIndex, 5)
    }
    
    func testDragSelectResetsGlobalHighlight() {
         // Setup: Global Highlight Active
         viewModel.didTapNumber(1)
         XCTAssertNotNil(viewModel.explicitHighlightedDigit)
         
         // Action: Start Drag
         viewModel.dragSelect(0, isStart: true)
         
         // Assert: Global Highlight Cleared
         XCTAssertNil(viewModel.explicitHighlightedDigit)
    }
}
