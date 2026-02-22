import XCTest
import SwiftUI
@testable import SudokuLogic

@MainActor
class SmartNoteTests: XCTestCase {
    
    var viewModel: SudokuGameViewModel!
    var levelViewModel: LevelViewModel!
    var container: ModelContainer!
    
    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, MoveHistory.self, configurations: config)
        levelViewModel = LevelViewModel(modelContext: container.mainContext)
        levelViewModel.loadLevelsFromJSON()
        viewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        viewModel.isNoteMode = true
    }

    func testSmartAdditiveLogic() {
        // 1. Select Cell 0 and Cell 1
        viewModel.toggleMultiSelectMode()
        viewModel.selectCell(0)
        viewModel.selectCell(1)
        
        // Setup: Cell 1 has note 5. Cell 0 has none.
        viewModel.cells[1].notes.insert(5)
        
        // 2. Input 5 -> Should ADD to Cell 0 (and keep in Cell 1)
        viewModel.toggleNote(5)
        XCTAssertTrue(viewModel.cells[0].notes.contains(5), "Cell 0 should gain note 5")
        XCTAssertTrue(viewModel.cells[1].notes.contains(5), "Cell 1 should keep note 5")
        
        // 3. Input 5 again -> Should REMOVE from BOTH (since both have it)
        viewModel.toggleNote(5)
        XCTAssertFalse(viewModel.cells[0].notes.contains(5), "Cell 0 should lose note 5")
        XCTAssertFalse(viewModel.cells[1].notes.contains(5), "Cell 1 should lose note 5")
    }
}
