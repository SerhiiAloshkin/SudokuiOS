import XCTest
@testable import SudokuiOS
import SwiftData

@MainActor
class GameSessionTests: XCTestCase {
    
    var viewModel: SudokuGameViewModel!
    var container: ModelContainer!
    var levelID = 999 
    
    override func setUp() async throws {
        // Mock Container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, MoveHistory.self, configurations: config)
        
        let levelVM = LevelViewModel(modelContext: container.mainContext)
        
        // Mock Level 999 in VM
        let mockLevel = SudokuLevel(id: levelID, isLocked: false, isSolved: false, board: String(repeating: "0", count: 81))
        levelVM.levels.append(mockLevel)
        
        viewModel = SudokuGameViewModel(levelID: levelID, levelViewModel: levelVM)
        // Ensure VM uses same context
        // SudokuGameViewModel uses levelViewModel's context by default indirectly via 'saveState' checks?
        // Actually SudokuGameViewModel accesses `parentViewModel.modelContext`.
    }
    
    func testSaveStateOnExit() {
        // 1. Simulate gameplay: Enter a number
        viewModel.selectedCellIndex = 0
        viewModel.enterNumber(5)
        
        // 2. Trigger Save (Simulating "Back" button action)
        viewModel.saveState()
        
        // 3. New VM (Simulating App Restart / Re-entry)
        let newLevelVM = LevelViewModel(modelContext: container.mainContext)
        // Mock level again or ensure it persists? Level data in VM is in-memory for 'levels' array, 
        // but progress is in SwiftData.
        let mockLevel = SudokuLevel(id: levelID, isLocked: false, isSolved: false, board: String(repeating: "0", count: 81))
        newLevelVM.levels.append(mockLevel)
        
        // Force load from persistence
        newLevelVM.loadProgressFromSuperRestrictedMock() // Wait, loadProgressFromSwiftData() is called in init
        // But since we are reusing the container, it should fetch the data.
        
        let newGameVM = SudokuGameViewModel(levelID: levelID, levelViewModel: newLevelVM)
        
        // 4. Verify Restoration
        // The cell at index 0 should have value 5
        XCTAssertEqual(newGameVM.cells[0].value, 5, "Persistence failed: Cell value not restored")
    }
    
    func testTimerContinuity() {
        // 1. Simulate time passing
        viewModel.timeElapsed = 120 // 2 minutes
        viewModel.saveState()
        
        // 2. Re-create VM
        let newLevelVM = LevelViewModel(modelContext: container.mainContext)
        let mockLevel = SudokuLevel(id: levelID, isLocked: false, isSolved: false, board: String(repeating: "0", count: 81))
        newLevelVM.levels.append(mockLevel)
        
        let newGameVM = SudokuGameViewModel(levelID: levelID, levelViewModel: newLevelVM)
        
        // 3. Verify Time
        XCTAssertEqual(newGameVM.timeElapsed, 120, "Timer did not resume from saved state")
    }
    
}

extension LevelViewModel {
    func loadProgressFromSuperRestrictedMock() {
        // Helper to force reload if needed, but init does it.
        loadProgressFromSwiftData()
    }
}
