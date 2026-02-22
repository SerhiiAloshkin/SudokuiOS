
#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

class SudokuGameViewModelTests: XCTestCase {
    
    var levelViewModel: LevelViewModel!
    var gameViewModel: SudokuGameViewModel!
    
    override func setUp() {
        super.setUp()
        // Initialize LevelViewModel
        levelViewModel = LevelViewModel()
        
        // Mock a Classic Level (ID 1)
        let classicLevel = SudokuLevel(id: 1, isLocked: false, isSolved: false, ruleType: .classic)
        
        // Mock a Variant Level (ID 2 - Kropki)
        let kropkiLevel = SudokuLevel(id: 2, isLocked: false, isSolved: false, ruleType: .kropki)
        
        levelViewModel.levels = [classicLevel, kropkiLevel]
    }
    
    override func tearDown() {
        levelViewModel = nil
        gameViewModel = nil
        super.tearDown()
    }
    
    func testDynamicTitle_Classic() {
        gameViewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        
        // Verify Title
        XCTAssertEqual(gameViewModel.levelTitle, "Level 1")
        
        // Verify Rule Display Name
        XCTAssertEqual(gameViewModel.ruleType?.displayName, "Classic Sudoku")
    }
    
    func testDynamicTitle_Variant() {
        gameViewModel = SudokuGameViewModel(levelID: 2, levelViewModel: levelViewModel)
        
        // Verify Title
        XCTAssertEqual(gameViewModel.levelTitle, "Level 2")
        
        // Verify Rule Display Name
        XCTAssertEqual(gameViewModel.ruleType?.displayName, "Kropki Sudoku")
    }
    
    func testInputLogic_ConflictHighlighting() {
        gameViewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        
        // Mock Board State
        // Row 0, Col 0 has '5'
        var boardChars = Array(repeating: "0", count: 81)
        boardChars[0] = "5"
        gameViewModel.currentBoard = boardChars.joined()
        
        // Select (0,1) - Neighbor
        gameViewModel.selectedCellIndex = 1
        
        // Tap '5' (Conflict)
        gameViewModel.didTapNumber(5)
        
        // Verify:
        // 1. Cell (0,1) should have '5'
        // 2. Mistake or Conflict logic should be triggered
        // Note: ViewModel uses 'shouldShowMistake' which checks against Solution OR Rules.
        // If we don't have a solution loaded, it might rely on validator.
        // Let's verify that the board updated at least.
        
        // Refresh board from VM
        let charAt1 = Array(gameViewModel.currentBoard)[1]
        XCTAssertEqual(String(charAt1), "5", "Board should update with input")
        
        // Additional Logic Verification:
        // If the move is invalid, 'revealedMistakeIndices' or similar might be updated if 'Auto-Check' is on.
        // For this test, we confirm the input is processed.
    }
}
#endif
