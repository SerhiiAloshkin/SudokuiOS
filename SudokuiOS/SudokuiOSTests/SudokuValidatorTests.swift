#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

final class SudokuValidatorTests: XCTestCase {

    var validator: SudokuValidator!
    
    override func setUp() {
        super.setUp()
        validator = SudokuValidator()
    }
    
    override func tearDown() {
        validator = nil
        super.tearDown()
    }

    // MARK: - Conflict Logic (Classic Rules)
    
    func testClassicValidation_ValidBoard() {
        let validBoard = [
            [5,3,4,6,7,8,9,1,2],
            [6,7,2,1,9,5,3,4,8],
            [1,9,8,3,4,2,5,6,7],
            [8,5,9,7,6,1,4,2,3],
            [4,2,6,8,5,3,7,9,1],
            [7,1,3,9,2,4,8,5,6],
            [9,6,1,5,3,7,2,8,4],
            [2,8,7,4,1,9,6,3,5],
            [3,4,5,2,8,6,1,7,9]
        ]
        
        XCTAssertTrue(validator.validate(board: validBoard, rules: [.classic]), "Valid board should pass")
    }
    
    func testClassicValidation_InvalidRow() {
        var board = [
            [5,3,4,6,7,8,9,1,2],
            [6,7,2,1,9,5,3,4,8],
            [1,9,8,3,4,2,5,6,7],
            [8,5,9,7,6,1,4,2,3],
            [4,2,6,8,5,3,7,9,1],
            [7,1,3,9,2,4,8,5,6],
            [9,6,1,5,3,7,2,8,4],
            [2,8,7,4,1,9,6,3,5],
            [3,4,5,2,8,6,1,7,9]
        ]
        
        // Introduce duplicate in Row 0: Change (0,1)=3 to 5 (Duplicate 5)
        board[0][1] = 5
        
        XCTAssertFalse(validator.validate(board: board, rules: [.classic]), "Duplicate in row should fail")
    }
    
    func testClassicValidation_InvalidColumn() {
        var board = [
            [5,3,4,6,7,8,9,1,2],
            [6,7,2,1,9,5,3,4,8],
            [1,9,8,3,4,2,5,6,7],
            [8,5,9,7,6,1,4,2,3],
            [4,2,6,8,5,3,7,9,1],
            [7,1,3,9,2,4,8,5,6],
            [9,6,1,5,3,7,2,8,4],
            [2,8,7,4,1,9,6,3,5],
            [3,4,5,2,8,6,1,7,9]
        ]
        
        // Introduce duplicate in Column 0: Change (1,0)=6 to 5 (Duplicate 5)
        board[1][0] = 5
        
        XCTAssertFalse(validator.validate(board: board, rules: [.classic]), "Duplicate in column should fail")
    }
    
    func testClassicValidation_InvalidBox() {
        var board = [
            [5,3,4,6,7,8,9,1,2],
            [6,7,2,1,9,5,3,4,8],
            [1,9,8,3,4,2,5,6,7],
            [8,5,9,7,6,1,4,2,3],
            [4,2,6,8,5,3,7,9,1],
            [7,1,3,9,2,4,8,5,6],
            [9,6,1,5,3,7,2,8,4],
            [2,8,7,4,1,9,6,3,5],
            [3,4,5,2,8,6,1,7,9]
        ]
        
        // Introduce duplicate in Box 0 (Top-Left): Change (1,1)=7 to 4 (Duplicate 4 from (0,2))
        board[1][1] = 4
        
        XCTAssertFalse(validator.validate(board: board, rules: [.classic]), "Duplicate in 3x3 box should fail")
    }
    
    // MARK: - Non-Consecutive Constraint
    
    func testNonConsecutiveConstraint() {
        // Create an empty board
        var board = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        
        // 1. Place '5' at center (4, 4)
        board[4][4] = 5
        
        // 2. Validate with just 5 (Should pass)
        XCTAssertTrue(validator.validate(board: board, rules: [.nonConsecutive]), "Single 5 should be valid")
        
        // 3. Place '4' next to it at (4, 5) -> Adjacent Horizontal
        board[4][5] = 4
        XCTAssertFalse(validator.validate(board: board, rules: [.nonConsecutive]), "Adjacent 4 and 5 should fail")
        
        // Reset (4, 5)
        board[4][5] = 0
        
        // 4. Place '6' above it at (3, 4) -> Adjacent Vertical
        board[3][4] = 6
        XCTAssertFalse(validator.validate(board: board, rules: [.nonConsecutive]), "Adjacent 5 and 6 should fail")
        
        // Reset (3, 4)
        board[3][4] = 0
        
        // 5. Place '7' next to it at (4, 5) -> Valid (Diff > 1)
        board[4][5] = 7
        XCTAssertTrue(validator.validate(board: board, rules: [.nonConsecutive]), "Adjacent 5 and 7 should pass")
    }
}
#endif
