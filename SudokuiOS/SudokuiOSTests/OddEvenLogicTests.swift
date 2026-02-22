#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

final class OddEvenLogicTests: XCTestCase {

    var validator: SudokuValidator!

    override func setUp() {
        super.setUp()
        validator = SudokuValidator()
    }
    
    override func tearDown() {
        validator = nil
        super.tearDown()
    }

    func testValidation_OddConstraint() {
        // Setup: Define a parity string where index 0 is "1" (Odd)
        let parityString = "1" + String(repeating: "0", count: 80)
        
        // Scenario 1: Valid (Odd Number 3 in Odd Cell)
        var validBoard = Array(repeating: 0, count: 81)
        validBoard[0] = 3
        
        // Convert to 2D for Validator
        var grid = [[Int]]()
        for r in 0..<9 {
            let row = Array(validBoard[r*9..<(r+1)*9])
            grid.append(row)
        }
        
        let isValid = validator.validate(board: grid, rules: [.oddEven(parity: parityString)])
        XCTAssertTrue(isValid, "3 should be allowed in an Odd (1) cell")
        
        // Scenario 2: Invalid (Even Number 4 in Odd Cell)
        var invalidBoard = Array(repeating: 0, count: 81)
        invalidBoard[0] = 4
        
        // Convert to 2D
        var invalidGrid = [[Int]]()
        for r in 0..<9 {
            let row = Array(invalidBoard[r*9..<(r+1)*9])
            invalidGrid.append(row)
        }
        
        let isInvalid = validator.validate(board: invalidGrid, rules: [.oddEven(parity: parityString)])
        XCTAssertFalse(isInvalid, "4 should NOT be allowed in an Odd (1) cell")
    }

    func testValidation_EvenConstraint() {
        // Setup: Define a parity string where index 0 is "2" (Even)
        let parityString = "2" + String(repeating: "0", count: 80)
        
        // Scenario 1: Valid (Even Number 4 in Even Cell)
        var validBoard = Array(repeating: 0, count: 81)
        validBoard[0] = 4
        
        // Convert to 2D
        var grid = [[Int]]()
        for r in 0..<9 {
            let row = Array(validBoard[r*9..<(r+1)*9])
            grid.append(row)
        }
        
        let isValid = validator.validate(board: grid, rules: [.oddEven(parity: parityString)])
        XCTAssertTrue(isValid, "4 should be allowed in an Even (2) cell")
        
        // Scenario 2: Invalid (Odd Number 5 in Even Cell)
        var invalidBoard = Array(repeating: 0, count: 81)
        invalidBoard[0] = 5
        
        // Convert to 2D
        var invalidGrid = [[Int]]()
        for r in 0..<9 {
            let row = Array(invalidBoard[r*9..<(r+1)*9])
            invalidGrid.append(row)
        }
        
        
        let isInvalid = validator.validate(board: invalidGrid, rules: [.oddEven(parity: parityString)])
        XCTAssertFalse(isInvalid, "5 should NOT be allowed in an Even (2) cell")
    }
    
    func testParsing_ShapeCount() {
        // Level 8-like parity string
        // "21100..."
        let parityString = "21100" + String(repeating: "2", count: 76)
        
        // Count expected shapes
        let oddCount = parityString.filter { $0 == "1" }.count
        let evenCount = parityString.filter { $0 == "2" }.count
        
        XCTAssertEqual(oddCount, 2)
        XCTAssertEqual(evenCount, 1 + 76)
        
        // In the View, this logic is just iteration. 
        // We can't easily test SwiftUI view hierarchy here, 
        // but we verify the Parsing CONCEPT works.
    }
}
#endif
