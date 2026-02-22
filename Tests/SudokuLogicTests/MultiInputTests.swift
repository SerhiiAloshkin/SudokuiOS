import XCTest
import SwiftUI
@testable import SudokuLogic

@MainActor
class MultiInputTests: XCTestCase {
    
    var viewModel: SudokuGameViewModel!
    var levelViewModel: LevelViewModel!
    var container: ModelContainer!
    
    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, MoveHistory.self, configurations: config)
        levelViewModel = LevelViewModel(modelContext: container.mainContext)
        levelViewModel.loadLevelsFromJSON()
        viewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        viewModel.isNoteMode = false // Ensure explicit mode is OFF
    }

    func testMultiSelectForcesNotes() {
        // 1. Select Cell 0 and Cell 1
        viewModel.toggleMultiSelectMode()
        viewModel.selectCell(0)
        viewModel.selectCell(1)
        
        // 2. Input 5 (with Note Mode OFF)
        viewModel.enterNumber(5)
        
        // Expectation: Both cells should have NOTE 5, not VALUE 5.
        XCTAssertEqual(viewModel.cells[0].value, 0, "Cell 0 should not have value 5")
        XCTAssertTrue(viewModel.cells[0].notes.contains(5), "Cell 0 should have note 5")
        
        XCTAssertEqual(viewModel.cells[1].value, 0, "Cell 1 should not have value 5")
        XCTAssertTrue(viewModel.cells[1].notes.contains(5), "Cell 1 should have note 5")
    }
    
    func testSingleSelectAllowsValue() {
        // 1. Select Cell 0 only
        viewModel.isMultiSelectMode = false
        viewModel.selectCell(0)
        
        // 2. Input 5
        viewModel.enterNumber(5)
        
        // Expectation: Cell should have VALUE 5
        XCTAssertEqual(viewModel.cells[0].value, 5, "Cell 0 should have value 5")
    }
}
