import XCTest
@testable import SudokuLogic

class PointingPairsSolverTests: XCTestCase {
    
    // Helper to make empty board
    var emptyBoard: String { String(repeating: "0", count: 81) }
    
    func testClaiming_RowToBox() {
        // Test Case: Claiming (Line-Box Reduction)
        // Scenario: Row 2 has candidates strictly in Box 0 (Cols 0, 1).
        // This implies that Box 0 cannot have candidates elsewhere (Rows 0, 1).
        
        var chars = Array(emptyBoard)
        
        // Block other cells in Row 2 (Cols 2..8) so 9 can ONLY be in Box 0 portion of Row 2.
        // Row 2 indices: 18..26.
        // Block 20..26.
        for i in 20...26 { chars[i] = "1" }
        
        // Ensure 18, 19 are empty (they are "0").
        // Now candidates for '9' in Row 2 are [18, 19]. Both in Box 0.
        // Should restrict '9' from rest of Box 0: indices 0,1,2, 9,10,11.
        
        let board = String(chars)
        let restrictions = PointingPairsSolver.getPointedRestrictions(board: board, digit: 9)
        
        XCTAssertTrue(restrictions.contains(0))
        XCTAssertTrue(restrictions.contains(1))
        XCTAssertTrue(restrictions.contains(2))
        XCTAssertTrue(restrictions.contains(9))
        XCTAssertTrue(restrictions.contains(10))
        XCTAssertTrue(restrictions.contains(11))
    }
    
    func testPointingPairs_BoxToRow() {
        // Test Case: Pointing Pairs
        // Scenario: Box 0 has candidates strictly in Row 0.
        // This implies Row 0 cannot have candidates outside Box 0.
        
        var chars = Array(emptyBoard)
        
        // Block other cells in Box 0 so 9 can ONLY be in Row 0 portion of Box 0.
        // Box 0 indices: 0,1,2, 9,10,11, 18,19,20.
        // Block 9,10,11, 18,19,20.
        for i in [9,10,11, 18,19,20] { chars[i] = "1" }
        
        // Ensure 0, 1, 2 are empty.
        // Now candidates for '9' in Box 0 are [0, 1, 2]. All in Row 0.
        // Should restrict '9' from rest of Row 0: indices 3..8.
        
        let board = String(chars)
        let restrictions = PointingPairsSolver.getPointedRestrictions(board: board, digit: 9)
        
        XCTAssertTrue(restrictions.contains(3))
        XCTAssertTrue(restrictions.contains(4))
        XCTAssertTrue(restrictions.contains(5))
        XCTAssertTrue(restrictions.contains(6))
        XCTAssertTrue(restrictions.contains(7))
        XCTAssertTrue(restrictions.contains(8))
    }
    
    func testPointingSingle_RestrictsRowAndCol() {
        // Test Case: Pointing Single (Specific User Request)
        // Scenario: "If the only one potential cell is highlighted in 3x3 block, then whole row and col have not to be highlighted for other 3x3 blocks"
        // Setup: Box 0 has only candidate at R0C0.
        // This implies 9 IS at R0C0.
        // It must restrict rest of Row 0 and rest of Col 0.
        
        var chars = Array(emptyBoard)
        
        // Block all cells in Box 0 EXCEPT R0C0 (Index 0).
        // Box 0 indices: 0..2, 9..11, 18..20.
        // Block 1,2, 9,10,11, 18,19,20.
        for i in [1,2, 9,10,11, 18,19,20] { chars[i] = "1" }
        
        let board = String(chars)
        let restrictions = PointingPairsSolver.getPointedRestrictions(board: board, digit: 9)
        
        // Should restrict Row 0 peers (Col 3..8)
        XCTAssertTrue(restrictions.contains(3), "Row peer 3 should be restricted")
        XCTAssertTrue(restrictions.contains(4), "Row peer 4 should be restricted")
        XCTAssertTrue(restrictions.contains(8), "Row peer 8 should be restricted")
        
        // Should restrict Col 0 peers (Row 3..8) -> Indices 27, 36...
        XCTAssertTrue(restrictions.contains(27), "Col peer 27 should be restricted")
        XCTAssertTrue(restrictions.contains(36), "Col peer 36 should be restricted")
        XCTAssertTrue(restrictions.contains(72), "Col peer 72 should be restricted")
    }
    func testCascadingRestrictions() {
        // Test Case: Cascading Pointing Pairs (Iterative Propagation)
        // Scenario:
        // 1. Box 0 has candidates for '9' ONLY at R0C0, R0C1 (Pointing Pair in Row 0).
        //    -> This restricts Row 0 for other boxes. Specifically R0C4.
        // 2. Box 1 normally has candidates at R0C4 and R1C4.
        //    -> BUT R0C4 is restricted by Box 0.
        //    -> So Box 1 effectively has candidate ONLY at R1C4 (Pointing Single).
        //    -> This should restrict rest of Row 1 and rest of Col 4.
        
        var chars = Array(emptyBoard)
        
        // Setup Box 0: Candidates at R0C0 (0), R0C1 (1).
        // Block rest of Box 0: 2, 9,10,11, 18,19,20.
        for i in [2, 9,10,11, 18,19,20] { chars[i] = "1" }
        
        // Setup Box 1: Candidates at R0C4 (4), R1C4 (13).
        // Block rest of Box 1: 3,5, 12,14, 21,22,23.
        for i in [3,5, 12,14, 21,22,23] { chars[i] = "1" }
        
        // Ensure candidates are empty "0"
        chars[0] = "0"; chars[1] = "0" // Box 0
        chars[4] = "0"; chars[13] = "0" // Box 1
        
        let board = String(chars)
        let restrictions = PointingPairsSolver.getPointedRestrictions(board: board, digit: 9)
        
        // 1. Primary Restriction: Box 0 restricts R0C4 (Index 4).
        XCTAssertTrue(restrictions.contains(4), "Box 0 Pair should restrict R0C4")
        
        // 2. Secondary Restriction (Cascade): 
        // Since R0C4 is restricted, Box 1 only has R1C4 (Index 13).
        // This makes R1C4 a Pointing Single.
        // It should restrict rest of Row 1 (e.g., R1C8 -> Index 17).
        // It should restrict rest of Col 4 (e.g., R5C4 -> Index 49).
        
        // Currently, without iteration, these will FAIL.
        XCTAssertTrue(restrictions.contains(17), "Cascade: R1C4 single should restrict Row 1 (R1C8)")
        XCTAssertTrue(restrictions.contains(49), "Cascade: R1C4 single should restrict Col 4 (R5C4)")
    func testHiddenSingleInRow_TriggersCascade() {
        // Scenario:
        // 1. Box 0 initially has candidates at R0C0 and R1C1.
        // 2. Row 0 has candidate ONLY at R0C0 (blocked elsewhere).
        //    -> "Claiming" (Line-Box) should eliminate R1C1 from Box 0 (since 9 MUST be in Row 0 part of Box 0).
        // 3. Now Box 0 has candidate ONLY at R0C0.
        //    -> "Pointing Single" should restrict Col 0 (outside Box 0).
        
        var chars = Array(emptyBoard)
        
        // Setup Box 0 Candidates: R0C0 (0), R1C1 (10).
        // Block other Box 0: 1,2, 9,11, 18,19,20.
        for i in [1,2, 9,11, 18,19,20] { chars[i] = "1" }
        
        // Setup Row 0: Only R0C0 is valid.
        // We blocked R0C1, R0C2 above.
        // Need to block R0C3..R0C8.
        for i in 3...8 { chars[i] = "1" }
        
        // Ensure candidates "0"
        chars[0] = "0"; chars[10] = "0"
        
        let board = String(chars)
        let restrictions = PointingPairsSolver.getPointedRestrictions(board: board, digit: 9)
        
        // 1. Claiming Logic: Row 0 has only R0C0.
        // This is strictly in Box 0.
        // So PointingPairsSolver normally restricts other cells in Box 0.
        // R1C1 (Index 10) is in Box 0 but NOT in Row 0.
        // So R1C1 should be restricted.
        XCTAssertTrue(restrictions.contains(10), "Claiming: Row 0 Single should eliminate R1C1")
        
        // 2. Cascade:
        // Since R1C1 is restricted, Box 0 now has only R0C0.
        // This makes R0C0 a Pointing Single.
        // It shold restrict Col 0 (e.g., R5C0 -> Index 45).
        XCTAssertTrue(restrictions.contains(45), "Cascade: New Pointing Single R0C0 should restrict Col 0")
    func testNoRestriction_SpreadCandidates() {
        // Test Case: False Positive Prevention
        // Scenario: Box 1 has candidates for '9' in Row 0 AND Row 2.
        // It should NOT restrict Row 0 or Row 2 outside the box.
        // User report: "R1C8 also has to be highlighted" (Implies it was hidden).
        
        var chars = Array(emptyBoard)
        
        // Setup Box 1:
        // Candidates at R0C4 (4) and R2C4 (22).
        // Block other cells in Box 1: 3,5, 12,13,14, 21,23.
        for i in [3,5, 12,13,14, 21,23] { chars[i] = "1" }
        
        let board = String(chars)
        let restrictions = PointingPairsSolver.getPointedRestrictions(board: board, digit: 9)
        
        // Candidates are (4, 22). Not aligned in Row. Aligned in Col 4? Yes.
        // But we are checking Row restrictions.
        // Should NOT restrict Row 0 (e.g., R0C8 -> Index 8).
        
        XCTAssertFalse(restrictions.contains(8), "Row 0 should NOT be restricted if Box 1 candidates are spread in Rows")
        
        // Note: It DOES restrict Col 4 (Pointing Pair in Col). But user issue was likely Row.
    func testUserScenario_Row0_HiddenSingle() {
        // Test Case: Specific User Scenario (Level 233)
        // Row 0: _ 6 _ | 8 _ _ | 1 _ _
        // Clue: 5. Digits: 1, 9.
        // User claims R1C8 (Index 7) should be highlighted.
        // We believe Index 7 is INVALID (Sum 0 != 5).
        // We believe Index 8 is VALID (Sum 5 possible if C7=5).
        
        var chars = Array(emptyBoard)
        // Setup Row 0 values
        chars[1] = "6"
        chars[3] = "8"
        chars[6] = "1"
        
        let board = String(chars)
        let rowClues = [5, -1, -1, -1, -1, -1, -1, -1, -1]
        
        // Check Sandwich Restrictions ONLY
        let sandwichRestrictions = SandwichSolver.getSandwichRestrictions(board: board, digit: 9, rowClues: rowClues, colClues: nil)
        
        // Index 7 (R0C7) -> Sandwich(1..9) -> Sum 0. Clue 5.
        // Should be RESTRICTED.
        XCTAssertTrue(sandwichRestrictions.contains(7), "User Scenario: R0C7 should be restricted (Sum 0 != 5)")
        
        // Index 8 (R0C8) -> Sandwich(1..9) -> Sum(R0C7).
        // If R0C7 is empty, it could be 5.
        // So R0C8 should NOT be restricted.
        XCTAssertFalse(sandwichRestrictions.contains(8), "User Scenario: R0C8 should be valid (Potential sum 5)")
    }
}
