import XCTest
@testable import SudokuLogic

class SandwichSolverTests: XCTestCase {
    
    // Helper to make empty board
    var emptyBoard: String { String(repeating: "0", count: 81) }
    
    func testRowConstraint_InvalidPlacement() {
        // Setup: Row 0 has Clue 5.
        // We placed '1' at R0C0.
        // We are checking candidates for '9'.
        // If we place '9' at R0C3, the sum between C0 and C3 is cell C1 + C2.
        // If C1=5, C2=2 -> Sum 7 > 5 -> Invalid.
        
        var chars = Array(emptyBoard)
        chars[0] = "1" // Fixed Crust positions
        chars[1] = "5"
        chars[2] = "2" // Sum is 7
        
        // R0C3 is the target candidate for '9'
        // R0C3 is empty "0"
        
        let board = String(chars)
        let rowClues = [5, 0, 0, 0, 0, 0, 0, 0, 0]
        
        let restrictions = SandwichSolver.getSandwichRestrictions(board: board, digit: 9, rowClues: rowClues, colClues: nil)
        
        // R0C3 (Index 3) should be restricted because placement there creates sum 7 > 5
        XCTAssertTrue(restrictions.contains(3), "Should restrict placement that exceeds row sum")
    }
    
    func testRowConstraint_ValidPlacement() {
        // Setup: Row 0 has Clue 5.
        // We placed '1' at R0C0.
        // We place '9' at R0C2.
        // Cell between is C1. If C1=5 -> Sum 5 == 5 -> Valid.
        
        var chars = Array(emptyBoard)
        chars[0] = "1"
        chars[1] = "5" // Sum 5 matches clue
        
        let board = String(chars)
        let rowClues = [5, 0, 0, 0, 0, 0, 0, 0, 0]
        
        let restrictions = SandwichSolver.getSandwichRestrictions(board: board, digit: 9, rowClues: rowClues, colClues: nil)
        
        // R0C2 (Index 2) should NOT be restricted
        XCTAssertFalse(restrictions.contains(2), "Should allow placement that matches row sum")
    }

    func testNoRestrictionsForNonCrust() {
        // Digit 5 should return empty set
        let restrictions = SandwichSolver.getSandwichRestrictions(board: emptyBoard, digit: 5, rowClues: [], colClues: [])
        XCTAssertTrue(restrictions.isEmpty)
    }
}
