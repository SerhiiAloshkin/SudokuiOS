import XCTest
@testable import SudokuiOS
import SwiftData

@MainActor
class SandwichLogicTests: XCTestCase {
    
    var viewModel: SudokuGameViewModel!
    var container: ModelContainer!
    var levelID = 888 
    
    override func setUp() async throws {
        // Mock Container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, MoveHistory.self, configurations: config)
        
        let levelVM = LevelViewModel(modelContext: container.mainContext)
        
        // Mock Level
        let mockLevel = SudokuLevel(id: levelID, isLocked: false, isSolved: false, board: String(repeating: "0", count: 81))
        levelVM.levels.append(mockLevel)
        
        viewModel = SudokuGameViewModel(levelID: levelID, levelViewModel: levelVM)
    }
    
    func testToggleCrossBasic() {
        viewModel.selectCell(0)
        
        // 1. Toggle ON
        viewModel.toggleCross()
        XCTAssertTrue(viewModel.cells[0].hasCross, "Cross should be True after toggle")
        
        // 2. Toggle OFF
        viewModel.toggleCross()
        XCTAssertFalse(viewModel.cells[0].hasCross, "Cross should be False after second toggle")
    }
    
    func testConflictWithNumber() {
        viewModel.selectCell(1)
        viewModel.enterNumber(5) // Set value
        
        // Try to toggle cross on a filled cell
        viewModel.toggleCross()
        XCTAssertFalse(viewModel.cells[1].hasCross, "Cross should NOT be applied to a cell with a value")
    }
    
    func testAutoClearOnEnterNumber() {
        viewModel.selectCell(2)
        viewModel.toggleCross()
        XCTAssertTrue(viewModel.cells[2].hasCross, "Setup failed: Cross not set")
        
        // Enter number
        viewModel.enterNumber(3)
        XCTAssertEqual(viewModel.cells[2].value, 3, "Value should be set")
        XCTAssertFalse(viewModel.cells[2].hasCross, "Cross should be cleared when number is entered")
    }
    
    func testPersistence() {
        // 1. Setup Cross
        viewModel.selectCell(3)
        viewModel.toggleCross()
        viewModel.saveState()
        
        // 2. Reload VM
        let newLevelVM = LevelViewModel(modelContext: container.mainContext)
        let mockLevel = SudokuLevel(id: levelID, isLocked: false, isSolved: false, board: String(repeating: "0", count: 81))
        newLevelVM.levels.append(mockLevel)
        // Force Load
        
        let newGameVM = SudokuGameViewModel(levelID: levelID, levelViewModel: newLevelVM)
        
        XCTAssertTrue(newGameVM.cells[3].hasCross, "Cross state should persist")
    }
    
    func testMultiSelectToggle() {
        // Select 4, 5, 6
        viewModel.selectCell(4)
        viewModel.toggleMultiSelectMode()
        viewModel.selectCell(5)
        viewModel.selectCell(6)
        
        // 5 is occupied
        viewModel.cells[5].value = 9
        
        // 1. Initial State: None have cross
        viewModel.toggleCross()
        
        XCTAssertTrue(viewModel.cells[4].hasCross, "Empty cell 4 should have cross")
        XCTAssertFalse(viewModel.cells[5].hasCross, "Occupied cell 5 should NOT have cross")
        XCTAssertTrue(viewModel.cells[6].hasCross, "Empty cell 6 should have cross")
        
        // 2. Remove State: All valid (4,6) have cross -> Remove
        viewModel.toggleCross()
        XCTAssertFalse(viewModel.cells[4].hasCross, "Empty cell 4 should default to off")
        XCTAssertFalse(viewModel.cells[6].hasCross, "Empty cell 6 should default to off")
        
        // 3. Mixed State (Add-Dominant)
        viewModel.cells[4].hasCross = true
        viewModel.cells[6].hasCross = false
        // Trigger toggle on 4,5,6 (5 ignored)
        viewModel.toggleCross()
        
        XCTAssertTrue(viewModel.cells[4].hasCross, "Cell 4 (already on) should STAY on")
        XCTAssertTrue(viewModel.cells[6].hasCross, "Cell 6 (off) should TURN on")
    }
    func testHistory() {
        // 1. Initial State
        viewModel.selectCell(7)
        XCTAssertFalse(viewModel.cells[7].hasCross)
        
        // 2. Perform Action
        viewModel.toggleCross()
        XCTAssertTrue(viewModel.cells[7].hasCross)
        
        // 3. Undo
        viewModel.undo()
        XCTAssertFalse(viewModel.cells[7].hasCross, "Undo should revert Cross state")
        
        // 4. Redo
        viewModel.redo()
        XCTAssertTrue(viewModel.cells[7].hasCross, "Redo should restore Cross state")
    }
    
    func testResetLevel() {
        // 1. Setup State: Solved + Crosses
        viewModel.selectCell(8)
        viewModel.toggleCross()
        viewModel.isSolved = true
        viewModel.saveState()
        
        // 2. Reset
        viewModel.restartLevel()
        
        // Wait for async task (in real app). Here we Mock/Check immediate effects if possible, 
        // but restartLevel is Task { @MainActor ... }. 
        // In Unit Test, we might need expectation or manual method call if not testing async.
        // Since restartLevel wraps in Task, we need generic wait.
        
        let expectation = XCTestExpectation(description: "Restart Level Async")
        
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            
            // Check In-Memory
            XCTAssertFalse(self.viewModel.isSolved, "isSolved should optionally be false (or kept? User said not marked as solved)")
            XCTAssertFalse(self.viewModel.cells[8].hasCross, "Cross should be cleared on reset")
            
            // Check Persistence via new VM
            let container = self.container!
            let levelVM = LevelViewModel(modelContext: container.mainContext)
            let newGameVM = SudokuGameViewModel(levelID: self.levelID, levelViewModel: levelVM)
            
            XCTAssertFalse(newGameVM.cells[8].hasCross, "Persistent Cross data should be cleared")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
