import XCTest
import SwiftData
@testable import SudokuLogic
import SwiftUI

@MainActor
final class MistakeModeTests: XCTestCase {
    
    var container: ModelContainer!
    var levelViewModel: LevelViewModel!
    var gameViewModel: SudokuGameViewModel!
    var appSettings: AppSettings!
    
    override func setUp() async throws {
        // Setup in-memory stack
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, AppSettings.self, configurations: config)
        levelViewModel = LevelViewModel(modelContext: container.mainContext)
        appSettings = AppSettings()
        container.mainContext.insert(appSettings)
        
        // Create a Mock Level (ID 999)
        // Correct: 1 2 3 ... 
        // Initial: 0 2 3 ...
        let solvedBoard = "123456789456789123789123456234567891567891234891234567345678912678912345912345678"
        var initialBoardChars = Array(solvedBoard)
        initialBoardChars[0] = "0" // Index 0 is empty
        let initialBoard = String(initialBoardChars)
        
        let level = SudokuLevel(id: 999, isLocked: false, isSolved: false, board: initialBoard, solution: solvedBoard)
        levelViewModel.levels.append(level)
        
        gameViewModel = SudokuGameViewModel(levelID: 999, levelViewModel: levelViewModel)
        gameViewModel.setSettings(appSettings)
    }
    
    func testImmediateModeMistakes() {
        // Arrange
        appSettings.mistakeMode = .immediate
        let targetIndex = 0 // The empty cell
        let wrongValue = 5
        
        // Act
        gameViewModel.selectCell(targetIndex)
        gameViewModel.enterNumber(wrongValue)
        
        // Assert
        XCTAssertTrue(gameViewModel.isMistake(at: targetIndex), "Value 5 should be a mistake at index 0 (Solution is 1)")
        XCTAssertTrue(gameViewModel.shouldShowMistake(at: targetIndex), "In Immediate Mode, mistake should be shown")
    }
    
    func testOnFullModeMistakesPartial() {
        // Arrange
        appSettings.mistakeMode = .onFull
        let targetIndex = 0
        let wrongValue = 5
        
        // Act
        gameViewModel.selectCell(targetIndex)
        gameViewModel.enterNumber(wrongValue) // Board is Full? No, wait. 
        // Our mock board has 81 cells. We set index 0 to '0'. 
        // So entering a number (even wrong) makes the board "Full" (no zeros).
        
        // We need a partial board. Let's clear another cell.
        let safeIndex = 1
        gameViewModel.selectCell(safeIndex) // Was '2'
        gameViewModel.erase() 
        XCTAssertFalse(gameViewModel.isBoardFull, "Board should not be full")
        
        // Now enter mistake at 0
        gameViewModel.selectCell(targetIndex)
        gameViewModel.enterNumber(wrongValue)
        
        // Assert
        XCTAssertTrue(gameViewModel.isMistake(at: targetIndex), "Value should be a logic mistake")
        XCTAssertFalse(gameViewModel.shouldShowMistake(at: targetIndex), "In OnFull Mode, mistake should NOT be shown if board is partial")
    }
    
    func testOnFullModeMistakesComplete() {
        // Arrange
        appSettings.mistakeMode = .onFull
        let targetIndex = 0
        let wrongValue = 5
        
        // Ensure board is full after our move. The mock board has only index 0 as empty.
        // So filling index 0 fills the board.
        
        // Act
        gameViewModel.selectCell(targetIndex)
        gameViewModel.enterNumber(wrongValue)
        
        XCTAssertTrue(gameViewModel.isBoardFull, "Board should be full")
        
        // Assert
        XCTAssertTrue(gameViewModel.isMistake(at: targetIndex))
        XCTAssertTrue(gameViewModel.shouldShowMistake(at: targetIndex), "In OnFull Mode, mistake should be shown when board is full")
    }
    
    func testNeverModeMistakes() {
        // Arrange
        appSettings.mistakeMode = .never
        let targetIndex = 0
        let wrongValue = 5
        
        // Act
        gameViewModel.selectCell(targetIndex)
        gameViewModel.enterNumber(wrongValue)
        
        // Assert
        XCTAssertTrue(gameViewModel.isMistake(at: targetIndex))
        XCTAssertFalse(gameViewModel.shouldShowMistake(at: targetIndex), "In Never Mode, mistake should NEVER be shown")
    }
    
    func testPersistenceUpdate() {
        // Arrange
        let targetIndex = 0
        let wrongValue = 5
        gameViewModel.selectCell(targetIndex)
        gameViewModel.enterNumber(wrongValue)
        
        // 1. Start with Never
        appSettings.mistakeMode = .never
        XCTAssertFalse(gameViewModel.shouldShowMistake(at: targetIndex))
        
        // 2. Switch to Immediate
        appSettings.mistakeMode = .immediate
        XCTAssertTrue(gameViewModel.shouldShowMistake(at: targetIndex), "Changing settings should update behavior immediately")
        
        // 3. Switch back
        appSettings.mistakeMode = .never
        XCTAssertFalse(gameViewModel.shouldShowMistake(at: targetIndex))
    }
}
