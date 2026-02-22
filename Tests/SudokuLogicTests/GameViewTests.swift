import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
final class GameViewTests: XCTestCase {
    
    var container: ModelContainer!
    var viewModel: LevelViewModel!
    
    override func setUp() async throws {
        // Create an in-memory container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, configurations: config)
        viewModel = LevelViewModel(modelContext: container.mainContext)
    }
    
    override func tearDown() {
        container = nil
        viewModel = nil
    }
    
    func testGameViewLoadsCorrectData() {
        // 1. Simulate View Loading
        // The view calls viewModel.loadLevelsFromJSON() if needed (init does this)
        
        // 2. Simulate View seeking Level 1
        let levelID = 1
        let level1 = viewModel.levels.first { $0.id == levelID }
        
        // 3. Verify Data Availability
        XCTAssertNotNil(level1, "Level 1 should exist in ViewModel")
        XCTAssertNotNil(level1?.board, "Level 1 board data should be loaded")
        
        // 4. Verify Content
        // We know Level 1 starts with "435..." from JSON
        if let board = level1?.board {
            XCTAssertEqual(board.count, 81, "Board data should be valid 81 char string")
        }
    }
    
    func testGameViewLoadsUserProgressIfAvailable() {
        // 1. Simulate saved user progress
        let customBoard = "12345..."
        viewModel.saveLevelProgress(levelId: 1, currentBoard: customBoard)
        
        // 2. Fetch Level 1 again
        let level1 = viewModel.levels.first { $0.id == 1 }
        
        // 3. Verify userProgress is set (which GameView prioritizes)
        XCTAssertEqual(level1?.userProgress, customBoard, "ViewModel should provide user progress string")
    }
    
    func testInputUpdatesPersistence() {
        // This test simulates the logic used in SudokuGameView.didTapNumber
        // Since View logic is hard to test directly without UI Tests, we verify the logic we put in the view
        // effectively works with the ViewModel.
        
        let levelID = 1
        let initialBoard = String(repeating: "0", count: 81)
        
        // Simulate initial save (e.g. game start) or just an update
        viewModel.saveLevelProgress(levelId: levelID, currentBoard: initialBoard)
        
        // Simulate tapping "5" at index 0
        var chars = Array(initialBoard)
        chars[0] = "5"
        let newBoard = String(chars)
        
        // Simulate the call the View makes
        viewModel.saveLevelProgress(levelId: levelID, currentBoard: newBoard)
        
        // Verify ViewModel State
        XCTAssertEqual(viewModel.levels[0].userProgress, newBoard)
        XCTAssertEqual(viewModel.levels[0].userProgress?.first, "5")
        
        // Verify Persistence
        // New ViewModel to simulate relaunch
        let newVM = LevelViewModel(modelContext: container.mainContext)
        XCTAssertEqual(newVM.levels[0].userProgress, newBoard, "Input should be persisted to SwiftData")
    }
}
