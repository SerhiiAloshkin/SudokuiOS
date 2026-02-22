import XCTest
import SwiftUI
@testable import SudokuLogic

@MainActor
class ColorTests: XCTestCase {
    
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

    func testColorToggle() {
        // 1. Select Cell 0
        viewModel.selectCell(0)
        
        // 2. Set Color 0 (e.g. Blue)
        viewModel.setCellColor(0)
        XCTAssertEqual(viewModel.cells[0].color, 0)
        
        // 3. Set Color 0 again -> Should Toggle Off (nil)
        viewModel.setCellColor(0)
        XCTAssertNil(viewModel.cells[0].color)
        
        // 4. Set Color 1 (Red)
        viewModel.setCellColor(1)
        XCTAssertEqual(viewModel.cells[0].color, 1)
        
        // 5. Set Color 0 -> Should Switch (not toggle off)
        viewModel.setCellColor(0)
        XCTAssertEqual(viewModel.cells[0].color, 0)
    }
}
