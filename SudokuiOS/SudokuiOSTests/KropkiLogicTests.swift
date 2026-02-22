#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

final class KropkiLogicTests: XCTestCase {

    var validator: SudokuValidator!

    override func setUp() {
        super.setUp()
        validator = SudokuValidator()
    }
    
    override func tearDown() {
        validator = nil
        super.tearDown()
    }

    // MARK: - White Dot Tests (Consecutive)
    func testWhiteDotValidation() {
        // Setup: White dot between (0,0) and (0,1)
        let whiteDots = [SudokuLevel.KropkiDot(r1: 0, c1: 0, r2: 0, c2: 1)]
        
        // Scenario 1: Valid (1 and 2, diff 1)
        var validBoard = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        validBoard[0][0] = 1
        validBoard[0][1] = 2
        
        XCTAssertTrue(validator.validate(board: validBoard, rules: [.kropki(white: whiteDots, black: [], negativeConstraint: false)]), "1 and 2 should be valid for white dot")
        
        // Scenario 2: Invalid (1 and 3, diff 2)
        var invalidBoard = validBoard
        invalidBoard[0][1] = 3
        
        XCTAssertFalse(validator.validate(board: invalidBoard, rules: [.kropki(white: whiteDots, black: [], negativeConstraint: false)]), "1 and 3 should be invalid for white dot")
    }
    
    // MARK: - Black Dot Tests (Ratio 1:2)
    func testBlackDotValidation() {
        // Setup: Black dot between (0,0) and (1,0)
        let blackDots = [SudokuLevel.KropkiDot(r1: 0, c1: 0, r2: 1, c2: 0)]
        
        // Scenario 1: Valid (1 and 2, ratio 1:2)
        var validBoard = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        validBoard[0][0] = 1
        validBoard[1][0] = 2
        
        XCTAssertTrue(validator.validate(board: validBoard, rules: [.kropki(white: [], black: blackDots, negativeConstraint: false)]), "1 and 2 should be valid for black dot")
        
        // Scenario 2: Valid (3 and 6, ratio 1:2)
        validBoard[0][0] = 6
        validBoard[1][0] = 3
        XCTAssertTrue(validator.validate(board: validBoard, rules: [.kropki(white: [], black: blackDots, negativeConstraint: false)]), "6 and 3 should be valid for black dot")
        
        // Scenario 3: Invalid (2 and 3, ratio not 1:2)
        validBoard[0][0] = 2
        validBoard[1][0] = 3
        XCTAssertFalse(validator.validate(board: validBoard, rules: [.kropki(white: [], black: blackDots, negativeConstraint: false)]), "2 and 3 should be invalid for black dot")
    }
    
    // MARK: - Negative Constraint Tests
    func testNegativeConstraint() {
        // Setup: No dots defined. Negative constraint ENABLED.
        // This means ANY adjacent pair satisfying Kropki rules (diff 1 or ratio 1:2) is INVALID unless a dot is there (which there isn't).
        
        // Scenario 1: Valid (1 and 3, no relation)
        var validBoard = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        validBoard[0][0] = 1
        validBoard[0][1] = 3
        
        XCTAssertTrue(validator.validate(board: validBoard, rules: [.kropki(white: [], black: [], negativeConstraint: true)]), "1 and 3 have no relation, so they are valid with negative constraint")
        
        // Scenario 2: Invalid (1 and 2, diff 1 -> Missing White Dot)
        var invalidBoardWhite = validBoard
        invalidBoardWhite[0][1] = 2
        
        XCTAssertFalse(validator.validate(board: invalidBoardWhite, rules: [.kropki(white: [], black: [], negativeConstraint: true)]), "1 and 2 (diff 1) without a white dot should be invalid")
        
        // Scenario 3: Invalid (1 and 2, ratio 1:2 -> Missing Black Dot)
        // Note: 1 and 2 satisfy BOTH. In Kropki, usually 1-2 is marked by Black dot if it satisfies both? Or either?
        // SudokuVariant rules usually say: "If consecutive, must have white. If ratio, must have black."
        // For 1-2, it satisfies BOTH. If either dot is missing but required, it fails.
        // In our implementation logic:
        // if abs(v1-v2)==1 return false
        // if v1==2*v2 return false
        
        // Let's test a ratio only pair: 3 and 6
        var invalidBoardBlack = validBoard
        invalidBoardBlack[0][0] = 3
        invalidBoardBlack[0][1] = 6
        
        XCTAssertFalse(validator.validate(board: invalidBoardBlack, rules: [.kropki(white: [], black: [], negativeConstraint: true)]), "3 and 6 (ratio 1:2) without a black dot should be invalid")
    }
}
#endif
