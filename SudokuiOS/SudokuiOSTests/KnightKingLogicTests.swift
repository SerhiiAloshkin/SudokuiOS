#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

final class KnightKingLogicTests: XCTestCase {

    var validator: SudokuValidator!

    override func setUp() {
        super.setUp()
        validator = SudokuValidator()
    }
    
    override func tearDown() {
        validator = nil
        super.tearDown()
    }

    // MARK: - Knight Validation
    func testKnightValidation() {
        // Setup: Board with 5 at [0,0]
        var board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        board[0][0] = 5
        
        // Scenario 1: Valid Move (Far away)
        var validBoard = board
        validBoard[0][1] = 6 // Different number, close by (valid for knight)
        XCTAssertTrue(validator.validate(board: validBoard, rules: [.knight]), "Different numbers should remain valid")
        
        // Scenario 2: Valid Knight Move (Different Number)
        validBoard = board
        validBoard[1][2] = 6 
        XCTAssertTrue(validator.validate(board: validBoard, rules: [.knight]), "Different number at knight move position is valid")
        
        // Scenario 3: Invalid Knight Move (Same Number at 1,2)
        // [0][0] is 5. Knight moves: (1,2), (2,1)
        var invalidBoard = board
        invalidBoard[1][2] = 5
        XCTAssertFalse(validator.validate(board: invalidBoard, rules: [.knight]), "Same number at [1,2] (Knight move from [0,0]) should be invalid")
        
        // Scenario 4: Invalid Knight Move (Same Number at 2,1)
        var invalidBoard2 = board
        invalidBoard2[2][1] = 5
        XCTAssertFalse(validator.validate(board: invalidBoard2, rules: [.knight]), "Same number at [2,1] (Knight move from [0,0]) should be invalid")
    }

    // MARK: - King Validation
    func testKingValidation() {
        // Setup: Board with 5 at [4,4] (Center)
        var board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        board[4][4] = 5
        
        // Scenario 1: Valid (Different number adjacent)
        var validBoard = board
        validBoard[3][3] = 6
        XCTAssertTrue(validator.validate(board: validBoard, rules: [.king]), "Different numbers adjacent should be valid")
        
        // Scenario 2: Invalid Diagonal (Same Number at 3,3)
        var invalidBoard = board
        invalidBoard[3][3] = 5
        XCTAssertFalse(validator.validate(board: invalidBoard, rules: [.king]), "Same number at [3,3] (Diagonal from [4,4]) should be invalid in King Sudoku")
        
        // Scenario 3: Invalid Side (Same Number at 4,5)
        var invalidBoard2 = board
        invalidBoard2[4][5] = 5
        XCTAssertFalse(validator.validate(board: invalidBoard2, rules: [.king]), "Same number at [4,5] (Adjacent to [4,4]) should be invalid in King Sudoku")
        
        // Scenario 4: Invalid Far Diagonal (Same Number at 5,5)
        var invalidBoard3 = board
        invalidBoard3[5][5] = 5
        XCTAssertFalse(validator.validate(board: invalidBoard3, rules: [.king]), "Same number at [5,5] (Diagonal from [4,4]) should be invalid")
    }
    // MARK: - Tutorial Visualizations (LevelVariantHelper)
    func testTutorialVisualizations() {
        // 1. Knight Center (4,4) -> Should have 8 invalid spots
        let knightMoves = LevelVariantHelper.getInvalidPositions(for: .knight, from: (4,4))
        XCTAssertEqual(knightMoves.count, 8, "Knight at center should have 8 moves")
        
        let expectedKnight = [(2,3), (2,5), (3,2), (3,6), (5,2), (5,6), (6,3), (6,5)]
        for move in expectedKnight {
            XCTAssertTrue(knightMoves.contains { $0 == move.0 && $1 == move.1 }, "Missing knight move: \(move)")
        }
        
        // 2. Knight Corner (0,0) -> Should have 2 invalid spots
        let knightCorner = LevelVariantHelper.getInvalidPositions(for: .knight, from: (0,0))
        XCTAssertEqual(knightCorner.count, 2, "Knight at corner should have 2 moves")
        XCTAssertTrue(knightCorner.contains { $0 == 1 && $1 == 2 })
        XCTAssertTrue(knightCorner.contains { $0 == 2 && $1 == 1 })
        
        // 3. King Center (4,4) -> Should have 8 invalid spots
        let kingMoves = LevelVariantHelper.getInvalidPositions(for: .king, from: (4,4))
        XCTAssertEqual(kingMoves.count, 8, "King at center should have 8 moves")
        // Check simple offset
        XCTAssertTrue(kingMoves.contains { $0 == 3 && $1 == 3 }) // Top-Left Diagonal
        
        // 4. King Corner (0,0) -> Should have 3 invalid spots
        let kingCorner = LevelVariantHelper.getInvalidPositions(for: .king, from: (0,0))
        XCTAssertEqual(kingCorner.count, 3, "King at corner should have 3 moves")
        XCTAssertTrue(kingCorner.contains { $0 == 0 && $1 == 1 }) // Right
        XCTAssertTrue(kingCorner.contains { $0 == 1 && $1 == 0 }) // Down
        XCTAssertTrue(kingCorner.contains { $0 == 1 && $1 == 1 }) // Diagonal
    }
}
#endif
