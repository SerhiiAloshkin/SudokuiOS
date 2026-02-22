import XCTest
import SwiftUI
@testable import SudokuLogic

@MainActor
class ClearColorTests: XCTestCase {
    
    var viewModel: SudokuGameViewModel!
    var levelViewModel: LevelViewModel!
    var container: ModelContainer!
    
    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, MoveHistory.self, configurations: config)
        levelViewModel = LevelViewModel(modelContext: container.mainContext)
        levelViewModel.loadLevelsFromJSON()
        viewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
    }

    func testClearCellColor() {
        // 1. Select Cell 5
        viewModel.selectCell(5)
        
        // 2. Set Green
        viewModel.setCellColor(2)
        XCTAssertEqual(viewModel.cells[5].color, 2)
        
        // 3. Explicit Clear
        viewModel.clearCellColor()
        XCTAssertNil(viewModel.cells[5].color)
        
        // 4. Undo Check (Should restore Green)
        viewModel.undo()
        XCTAssertEqual(viewModel.cells[5].color, 2)
    }
}
