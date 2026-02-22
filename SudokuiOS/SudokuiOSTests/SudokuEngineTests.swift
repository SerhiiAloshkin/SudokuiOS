
#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

final class SudokuEngineTests: XCTestCase {
    
    var validator: SudokuValidator!
    
    override func setUp() {
        super.setUp()
        validator = SudokuValidator()
    }
    
    // MARK: - Rule Constraints: Classic (3x3 Box Boundary)
    
    func testClassicBoxBoundaryLogic() {
        var board = SudokuEngineTests.emptyBoard()
        
        // Place '5' at (0,0) [Top-Left Box]
        board[0][0] = 5
        
        // Try placing '5' at (1,1) [Same Box] -> Should Fail
        let sameBoxInvalid = validator.isValidMove(board, row: 1, col: 1, val: 5)
        XCTAssertFalse(sameBoxInvalid, "Classic: Duplicate in same 3x3 box should be invalid")
        
        // Try placing '5' at (0,3) [Different Box, Same Row] -> Should Fail (Row Rule)
        let sameRowInvalid = validator.isValidMove(board, row: 0, col: 3, val: 5)
        XCTAssertFalse(sameRowInvalid, "Classic: Duplicate in same row should be invalid")
        
        // Try placing '5' at (3,3) [Different Box, Different Row/Col] -> Should Pass
        let validMove = validator.isValidMove(board, row: 3, col: 3, val: 5)
        XCTAssertTrue(validMove, "Classic: Non-conflicting placement should be valid")
    }
    
    // MARK: - Rule Constraints: Non-Consecutive
    
    func testNonConsecutiveConstraintLogic() {
        var board = SudokuEngineTests.emptyBoard()
        board[1][1] = 5
        
        // Orthogonal Neighbors
        let neighbors = [(0,1), (1,0), (1,2), (2,1)]
        let rules: [SudokuRule] = [.nonConsecutive]
        
        for (r, c) in neighbors {
            // Try '4' (Diff 1)
            board[r][c] = 4
            XCTAssertFalse(validator.validate(board: board, rules: rules), "Non-Consecutive: Neighbor \(r),\(c) with val 4 should fail")
            
            // Try '6' (Diff 1)
            board[r][c] = 6
            XCTAssertFalse(validator.validate(board: board, rules: rules), "Non-Consecutive: Neighbor \(r),\(c) with val 6 should fail")
            
            // Try '3' (Diff 2) -> Should Pass (if isolated)
            board[r][c] = 3
            XCTAssertTrue(validator.validate(board: board, rules: rules), "Non-Consecutive: Neighbor \(r),\(c) with val 3 should pass")
            
            // Reset
            board[r][c] = 0
        }
    }
    
    // MARK: - Rule Constraints: Knight Move
    
    func testKnightConstraintLogic() {
        var board = SudokuEngineTests.emptyBoard()
        board[4][4] = 5 // Center
        
        let rules: [SudokuRule] = [.knight]
        
        // Knight moves from (4,4): (2,3), (2,5), (3,2), (3,6), (5,2), (5,6), (6,3), (6,5)
        let knightMoves = [
            (2,3), (2,5), (3,2), (3,6),
            (5,2), (5,6), (6,3), (6,5)
        ]
        
        for (r, c) in knightMoves {
            board[r][c] = 5
            XCTAssertFalse(validator.validate(board: board, rules: rules), "Knight: Same value at \(r),\(c) should fail")
            board[r][c] = 0 // Reset
        }
        
        // Check non-knight move (e.g., (4,5) adjacent) -> Should Pass Knight Rule (ignoring Classic)
        // Note: SudokuValidator.validate combines ALL rules passed. If we pass ONLY .knight, it checks knight moves.
        // But isValidMove default checks classic too. Use validate(board:rules:) for pure rule check if implemented that way,
        // or ensure no classic conflict.
        
        board[4][5] = 5 // Adjacent, NOT knight move
        // Classic rule would fail this, but let's check if the generic validate handles strict rule separation?
        // SudokuValidator.validate typically checks *all* active rules.
        // If we only pass [.knight], it *should* theoretically only check knight if implemented granularly,
        // but often Classic is implicit base.
        // Let's assume Classic is separate or we check a valid spot.
        
        // (4,8) is same row (Classic fail).
        // (0,0) is far away, no knight connection.
        board[0][0] = 5
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Knight: Unrelated position should pass")
    }
    
    // MARK: - Rule Constraints: King Move
    
    func testKingConstraintLogic() {
        var board = SudokuEngineTests.emptyBoard()
        board[1][1] = 5
        
        let rules: [SudokuRule] = [.king]
        
        // All 8 neighbors (orthogonal + diagonal)
        for r in 0...2 {
            for c in 0...2 {
                if r == 1 && c == 1 { continue }
                
                board[r][c] = 5
                XCTAssertFalse(validator.validate(board: board, rules: rules), "King: Neighbor \(r),\(c) should fail with same value")
                
                board[r][c] = 0 // Reset
            }
        }
    }
    
    // MARK: - Rule Constraints: Thermometer
    
    func testThermometerStrictlyIncreasing() {
        var board = SudokuEngineTests.emptyBoard()
        
        // Path: (0,0) -> (0,1) -> (0,2) [Row 0, first 3 cells]
        let path = [[0,0], [0,1], [0,2]] // [[Int]] format for coords
        
        let pathStruct: [[[Int]]] = [path] // Array of paths
        let rules: [SudokuRule] = [.thermo(paths: pathStruct)]
        
        // Case 1: Valid Strict Increase (1, 2, 3)
        board[0][0] = 1
        board[0][1] = 2
        board[0][2] = 3
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Thermo: 1->2->3 should pass")
        
        // Case 2: Decrease (1, 5, 4)
        board[0][0] = 1
        board[0][1] = 5
        board[0][2] = 4
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Thermo: 1->5->4 should fail (decrease)")
        
        // Case 3: Equal (1, 2, 2)
        board[0][0] = 1
        board[0][1] = 2
        board[0][2] = 2
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Thermo: 1->2->2 should fail (equal)")
        
        // Case 4: Gap in numbers but strict increase (1, 5, 9)
        board[0][0] = 1
        board[0][1] = 5
        board[0][2] = 9
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Thermo: 1->5->9 should pass")
    }
    
    // MARK: - Rule Constraints: Arrow Sums
    
    func testArrowSumLogic() {
        var board = SudokuEngineTests.emptyBoard()
        
        // Arrow: Circle at (0,0), Path -> (0,1), (0,2)
        // Sum of (0,1) + (0,2) must equal (0,0)
        let arrow = SudokuLevel.Arrow(circle: [0,0], lines: [[0,1], [0,2]])
        let rules: [SudokuRule] = [.arrow([arrow])]
        
        // Case 1: Valid Sum (7 = 3 + 4)
        board[0][0] = 7
        board[0][1] = 3
        board[0][2] = 4
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Arrow: 7 = 3 + 4 should pass")
        
        // Case 2: Invalid Sum (7 != 3 + 5)
        board[0][0] = 7
        board[0][1] = 3
        board[0][2] = 5
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Arrow: 7 != 3 + 5 should fail")
        
        // Case 3: Empty Cell (Should be ignored or handled gracefully? Validator typically skips 0s)
        board[0][2] = 0
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Arrow: Incomplete arrow should pass (ignore 0)")
        
        // Case 4: Single Cell Arrow (Direct copy)
        // Circle (1,0) -> Line (1,1)
        let simpleArrow = SudokuLevel.Arrow(circle: [1,0], lines: [[1,1]])
        let rulesSimple = [.arrow([simpleArrow])] as [SudokuRule]
        
        board[1][0] = 5
        board[1][1] = 5
        XCTAssertTrue(validator.validate(board: board, rules: rulesSimple), "Arrow: Single cell copy 5=5 should pass")
        
        board[1][1] = 4
        XCTAssertFalse(validator.validate(board: board, rules: rulesSimple), "Arrow: Single cell copy 5!=4 should fail")
    }
    
    // MARK: - Rule Constraints: Killer Cages
    
    func testKillerCageLogic() {
        var board = SudokuEngineTests.emptyBoard()
        
        // Killer Cage: Sum 7, Cells (0,0) and (0,1)
        let cage = SudokuLevel.KillerCage(sum: 7, cells: [[0,0], [0,1]])
        let rules: [SudokuRule] = [.killer([cage])]
        
        // Case 1: Valid Sum (3 + 4 = 7), Unique
        board[0][0] = 3
        board[0][1] = 4
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Killer: 3+4=7 should pass")
        
        // Case 2: Valid Sum (4 + 3 = 7), Unique (Order doesn't matter)
        board[0][0] = 4
        board[0][1] = 3
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Killer: 4+3=7 should pass")
        
        // Case 3: Invalid Sum (3 + 5 = 8)
        board[0][0] = 3
        board[0][1] = 5
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Killer: 3+5=8 should fail (Sum mismatch)")
        
        // Case 4: Duplicate Number Logic check
        // Ideally, Killer Cages also enforce uniqueness within the cage.
        // But for size 2, uniqueness is implied if Sum is odd (can't be X+X).
        // Let's try Sum 6 with [3, 3].
        let cage6 = SudokuLevel.KillerCage(sum: 6, cells: [[0,0], [0,1]])
        let rules6: [SudokuRule] = [.killer([cage6])]
        
        board[0][0] = 3
        board[0][1] = 3
        // If standard Sudoku rules apply, this fails Row constraint anyway.
        // But Killer constraint itself usually implies uniqueness.
        // Validator typically checks uniqueness within cage too.
        XCTAssertFalse(validator.validate(board: board, rules: rules6), "Killer: 3+3=6 should fail (Duplicate in cage)")
        
        // Case 5: Empty Cell (Incomplete) -> Should Pass (Ignore 0s)
        board[0][0] = 3
        board[0][1] = 0
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Killer: 3+0 should pass (Incomplete)")
    }
    
    // MARK: - Rule Constraints: Sandwich
        
    func testSandwichConstraintLogic() {
        var board = SudokuEngineTests.emptyBoard()
        
        // Row 0: 1 at (0,0), 9 at (0,4). Cells between indices 1,2,3.
        // Sum should be board[0][1] + board[0][2] + board[0][3]
        board[0][0] = 1
        board[0][4] = 9
        
        board[0][1] = 2
        board[0][2] = 3
        board[0][3] = 4 // Sum = 2+3+4 = 9
        
        let rowClues: [Int?] = [9, nil, nil, nil, nil, nil, nil, nil, nil]
        let colClues: [Int?] = Array(repeating: nil, count: 9)
        
        let rules: [SudokuRule] = [.sandwich(rows: rowClues, cols: colClues)]
        
        // Case 1: Valid Sum (9 == 9)
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Sandwich: Sum 9 matches clue 9")
        
        // Case 2: Invalid Sum (Change middle value)
        board[0][2] = 5 // Sum = 2+5+4 = 11
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Sandwich: Sum 11 mismatches clue 9")
        
        // Case 3: Empty cells between (Should pass if we treat 0 as 0? Or fail? Validator treats 0 as 0 usually or skips.
        // calcSandwichSum logic checks `minIdx` and `maxIdx`. If 1 and 9 exist, it sums.
        // If 0s are present, they add 0.
        // So strict sum check applies.
        board[0][2] = 0 // Sum = 2+0+4 = 6
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Sandwich: Sum 6 mismatches clue 9")
        
        // Case 4: Missing 1 or 9
        board[0][4] = 0 // 9 removed
        // Logic says calculateSandwichSum returns nil.
        // If nil, loop continues (ignores).
        // So implicit pass if board incomplete?
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Sandwich: Missing 1 or 9 should be ignored (incomplete)")
    }
    
    // MARK: - UI State Verification
    
    func testUIState_StaticRuleCardView_DataIntegrity() {
        // Verify that StaticRuleCardView returns non-empty data for all rule types
        for rule in SudokuRuleType.allCases {
            let view = StaticRuleCardView(ruleType: rule)
            
            XCTAssertFalse(view.incorrectContent.isEmpty, "Rule \(rule) should have incorrect example data")
            XCTAssertFalse(view.correctContent.isEmpty, "Rule \(rule) should have correct example data")
            
            // Verify specific known data points
            if rule == .classic {
                XCTAssertEqual(view.incorrectContent.count, 3, "Classic incorrect example should have 3 cells")
            }
        }
    }
    
    func testSandwichSumClueMismatch() {
        var board = SudokuEngineTests.emptyBoard()
        
        // Setup: 1, 3, 5, 9 in Row 0 => Sum is 8
        board[0][0] = 1
        board[0][1] = 3
        board[0][2] = 5
        board[0][3] = 9
        
        // Clue: 7 (Mismatch)
        let rowClues: [Int?] = [7, nil, nil, nil, nil, nil, nil, nil, nil]
        let colClues: [Int?] = Array(repeating: nil, count: 9)
        let rules: [SudokuRule] = [.sandwich(rows: rowClues, cols: colClues)]
        
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Sandwich: Sum 8 should fail against Clue 7")
        
        // Clue: 8 (Match)
        let rowCluesMatch: [Int?] = [8, nil, nil, nil, nil, nil, nil, nil, nil]
        let rulesMatch: [SudokuRule] = [.sandwich(rows: rowCluesMatch, cols: colClues)]
        
        XCTAssertTrue(validator.validate(board: board, rules: rulesMatch), "Sandwich: Sum 8 should pass against Clue 8")
    }
    
    func testLayoutConsistency() {
        // Ensure every rule type has valid tutorial content
        for rule in SudokuRuleType.allCases {
            let view = StaticRuleCardView(ruleType: rule)
            
            // Check Content
            XCTAssertFalse(view.incorrectContent.isEmpty, "Rule \(rule) missing incorrect example")
            XCTAssertFalse(view.correctContent.isEmpty, "Rule \(rule) missing correct example")
            
            // Check Descriptions
            XCTAssertFalse(view.title.isEmpty, "Rule \(rule) missing title")
            XCTAssertFalse(view.description.isEmpty, "Rule \(rule) missing description")
            
            // Check Sandwich specific (optional but good sanity check)
            if rule == .sandwich {
                // Verify we have clues in the UI logic? 
                // StaticRuleCardView logic is internal to body, hard to test via Unit Test unless we expose it.
                // But we can verify the data content at least.
                let incorrect = view.incorrectContent
                XCTAssertTrue(incorrect.contains { $0.val == "1" }, "Sandwich incorrect should have '1'")
                XCTAssertTrue(incorrect.contains { $0.val == "9" }, "Sandwich incorrect should have '9'")
            }
        }
    }
    
    // MARK: - Rule Constraints: Kropki Dots
    
    func testWhiteDotLogic() {
        var board = SudokuEngineTests.emptyBoard()
        
        // White Dot between (0,0) and (0,1) -> Diff must be 1
        let dot = SudokuLevel.KropkiDot(r1: 0, c1: 0, r2: 0, c2: 1)
        let rules: [SudokuRule] = [.kropki(white: [dot], black: [], negativeConstraint: false)]
        
        // Case 1: Valid Diff 1 (4, 5)
        board[0][0] = 4
        board[0][1] = 5
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Kropki White: 4-5 (Diff 1) should pass")
        
        // Case 2: Invalid Diff (4, 6)
        board[0][0] = 4
        board[0][1] = 6
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Kropki White: 4-6 (Diff 2) should fail")
    }
    
    func testBlackDotLogic() {
        var board = SudokuEngineTests.emptyBoard()
        
        // Black Dot between (0,0) and (0,1) -> Ratio must be 2:1
        let dot = SudokuLevel.KropkiDot(r1: 0, c1: 0, r2: 0, c2: 1)
        let rules: [SudokuRule] = [.kropki(white: [], black: [dot], negativeConstraint: false)]
        
        // Case 1: Valid Ratio (3, 6)
        board[0][0] = 3
        board[0][1] = 6
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Kropki Black: 3-6 (Ratio 2) should pass")
        
        // Case 2: Valid Ratio (6, 3)
        board[0][0] = 6
        board[0][1] = 3
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Kropki Black: 6-3 (Ratio 2) should pass")
        
        // Case 3: Invalid Ratio (3, 5)
        board[0][0] = 3
        board[0][1] = 5
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Kropki Black: 3-5 (Ratio 1.66) should fail")
        
        // Case 4: 1-2 Pair (Valid for Black Dot too)
        board[0][0] = 1
        board[0][1] = 2
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Kropki Black: 1-2 (Ratio 2) should pass")
    }
    
    func testNegativeKropkiLogic() {
        var board = SudokuEngineTests.emptyBoard()
        
        // Negative Constraint: No dots defined. Any adjacent pair with Diff 1 or Ratio 2 should fail.
        let rules: [SudokuRule] = [.kropki(white: [], black: [], negativeConstraint: true)]
        
        // Case 1: 4-5 (Diff 1) with NO dot -> Should Fail
        board[0][0] = 4
        board[0][1] = 5
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Kropki Negative: 4-5 without dot should fail")
        
        // Case 2: 3-6 (Ratio 2) with NO dot -> Should Fail
        board[0][0] = 3
        board[0][1] = 6
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Kropki Negative: 3-6 without dot should fail")
        
        // Case 3: 4-6 (Diff 2, Ratio 1.5) with NO dot -> Should Pass
        board[0][0] = 4
        board[0][1] = 6
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Kropki Negative: 4-6 (No relation) should pass")
        
        // Case 4: 1-2 (Diff 1 AND Ratio 2) with NO dot -> Should Fail
        board[0][0] = 1
        board[0][1] = 2
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Kropki Negative: 1-2 without dot should fail")
    }

    func testBlackDotFailure() {
        var board = SudokuEngineTests.emptyBoard()
        // Black Dot between (0,0) and (0,1)
        let dot = SudokuLevel.KropkiDot(r1: 0, c1: 0, r2: 0, c2: 1)
        let rules: [SudokuRule] = [.kropki(white: [], black: [dot], negativeConstraint: false)]
        
        // Invalid Ratio (3, 5) -> Ratio 1.66
        board[0][0] = 3
        board[0][1] = 5
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Kropki Black: 3-5 (Ratio != 2) should fail")
    }
    
    func testWhiteDotFailure() {
        var board = SudokuEngineTests.emptyBoard()
        // White Dot between (0,0) and (0,1)
        let dot = SudokuLevel.KropkiDot(r1: 0, c1: 0, r2: 0, c2: 1)
        let rules: [SudokuRule] = [.kropki(white: [dot], black: [], negativeConstraint: false)]
        
        // Invalid Diff (4, 6) -> Diff 2
        board[0][0] = 4
        board[0][1] = 6
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Kropki White: 4-6 (Diff != 1) should fail")
    }
    
    func testNegativeKropkiConsecutive() {
        var board = SudokuEngineTests.emptyBoard()
        // Negative Constraint Active, No Dots
        let rules: [SudokuRule] = [.kropki(white: [], black: [], negativeConstraint: true)]
        
        // Invalid: Consecutive (4, 5) without White Dot
        board[0][0] = 4
        board[0][1] = 5
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Negative Kropki: 4-5 without dot should fail")
    }
    
    func testNegativeKropkiRatio() {
        var board = SudokuEngineTests.emptyBoard()
        // Negative Constraint Active, No Dots
        let rules: [SudokuRule] = [.kropki(white: [], black: [], negativeConstraint: true)]
        
        // Invalid: Ratio (3, 6) without Black Dot
        board[0][0] = 3
        board[0][1] = 6
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Negative Kropki: 3-6 without dot should fail")
    }

    // 1-2 Interaction Tests
    func testOneTwoWhiteDot() {
        var board = SudokuEngineTests.emptyBoard()
        // White Dot between (0,0) and (0,1)
        let dot = SudokuLevel.KropkiDot(r1: 0, c1: 0, r2: 0, c2: 1)
        let rules: [SudokuRule] = [.kropki(white: [dot], black: [], negativeConstraint: false)]
        
        // 1-2 (Diff 1) -> Valid
        board[0][0] = 1
        board[0][1] = 2
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Kropki: 1-2 with White Dot should be Valid")
    }
    
    func testOneTwoBlackDot() {
        var board = SudokuEngineTests.emptyBoard()
        // Black Dot between (0,0) and (0,1)
        let dot = SudokuLevel.KropkiDot(r1: 0, c1: 0, r2: 0, c2: 1)
        let rules: [SudokuRule] = [.kropki(white: [], black: [dot], negativeConstraint: false)]
        
        // 1-2 (Ratio 2) -> Valid
        board[0][0] = 1
        board[0][1] = 2
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Kropki: 1-2 with Black Dot should be Valid")
    }
    
    func testNegativeKropkiMissingDot() {
        var board = SudokuEngineTests.emptyBoard()
        let rules: [SudokuRule] = [.kropki(white: [], black: [], negativeConstraint: true)]
        
        // 1-2 without any dot -> Invalid (Needs White OR Black)
        board[0][0] = 1
        board[0][1] = 2
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Negative Kropki: 1-2 without dot should fail")
        
        // 1-3 without any dot -> Valid (Diff 2, Ratio 3)
        board[0][0] = 1
        board[0][1] = 3
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Negative Kropki: 1-3 without dot should be Valid")
    }
    
    func testNegativeConstraintComplexNeighbors() {
        var board = SudokuEngineTests.emptyBoard()
        // Negative Constraint Active, No Dots
        let rules: [SudokuRule] = [.kropki(white: [], black: [], negativeConstraint: true)]
        
        // Center: 4 at (1,1)
        board[1][1] = 4
        
        // Neighbors: 3 (Left), 5 (Right), 2 (Top), 8 (Bottom)
        // All should fail because they imply a relationship (Diff 1 or Ratio 2) but have no dot.
        
        // 1. Left Neighbor (1,0) = 3 (Diff 1 with 4) -> Fail
        board[1][0] = 3
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Negative Kropki: 4-3 (Diff 1) without dot should fail")
        board[1][0] = 0 // Clear
        
        // 2. Right Neighbor (1,2) = 5 (Diff 1 with 4) -> Fail
        board[1][2] = 5
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Negative Kropki: 4-5 (Diff 1) without dot should fail")
        board[1][2] = 0 // Clear
        
        // 3. Top Neighbor (0,1) = 2 (Ratio 2 with 4) -> Fail
        board[0][1] = 2
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Negative Kropki: 4-2 (Ratio 2) without dot should fail")
        board[0][1] = 0 // Clear
        
        // 4. Bottom Neighbor (2,1) = 8 (Ratio 2 with 4) -> Fail
        board[2][1] = 8
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Negative Kropki: 4-8 (Ratio 2) without dot should fail")
        board[2][1] = 0 // Clear
    }

    // MARK: - Odd/Even Constraint Tests
    
    func testEvenShadedConstraint() {
        var board = SudokuEngineTests.emptyBoard()
        // Define Parity String: 81 chars.
        // Let (0,0) be "2" (Even). All others "0" (None).
        let parity = "2" + String(repeating: "0", count: 80)
        
        let rules: [SudokuRule] = [.oddEven(parity: parity)]
        
        // Test Strict Failure for ALL Odd numbers
        let oddNumbers = [1, 3, 5, 7, 9]
        for odd in oddNumbers {
            board[0][0] = odd
            XCTAssertFalse(validator.validate(board: board, rules: rules), "Odd/Even: \(odd) in Even Cell should fail")
            board[0][0] = 0 // Reset
        }
        
        // Test Success for Even number
        board[0][0] = 4
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Odd/Even: 4 (Even) in Even Cell should pass")
    }
    
    func testOddCircleConstraint() {
        var board = SudokuEngineTests.emptyBoard()
        // Define Parity String: 81 chars.
        // Let (0,1) be "1" (Odd). Index 1.
        let parity = "01" + String(repeating: "0", count: 79)
        
        let rules: [SudokuRule] = [.oddEven(parity: parity)]
        
        // Test Strict Failure for ALL Even numbers
        let evenNumbers = [2, 4, 6, 8]
        for even in evenNumbers {
            board[0][1] = even
            XCTAssertFalse(validator.validate(board: board, rules: rules), "Odd/Even: \(even) in Odd Cell should fail")
            board[0][1] = 0 // Reset
        }
        
        // Test Success for Odd number
        board[0][1] = 7
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Odd/Even: 7 (Odd) in Odd Cell should pass")
    }
    
    func testNegativeKropkiWithOddEven() {
        var board = SudokuEngineTests.emptyBoard()
        
        // Setup:
        // (0,0) is Even (Square).
        // (0,1) is Odd (Circle).
        // No dots between them.
        // Negative Constraint Active.
        
        let parity = "21" + String(repeating: "0", count: 79)
        
        // Combined Rules
        let rules: [SudokuRule] = [
            .kropki(white: [], black: [], negativeConstraint: true),
            .oddEven(parity: parity)
        ]
        
        // Case 1: Odd/Even Correct, but Kropki Failure
        // (0,0)=2 (Even), (0,1)=3 (Odd).
        // Diff is 1 -> Kropki Violation (No white dot).
        board[0][0] = 2
        board[0][1] = 3
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Combined: 2-3 (Diff 1) fails Negative Kropki even if Parity is correct")
        
        // Case 2: Kropki Correct, but Odd/Even Failure
        // (0,0)=3 (Odd in Even Cell), (0,1)=5 (Odd).
        // Diff 2 -> Kropki OK.
        // But (0,0) violates Parity.
        board[0][0] = 3
        board[0][1] = 5
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Combined: 3 in Even Cell fails Parity even if Kropki is valid")
        
        // Case 3: Both Correct
        // (0,0)=2 (Even), (0,1)=5 (Odd).
        // Diff 3 -> Kropki OK.
        // Parity OK.
        board[0][0] = 2
        board[0][1] = 5
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Combined: 2-5 passes both Kropki and Parity constraints")
    }
    
    func testCombinedVariantLogic() {
        var board = SudokuEngineTests.emptyBoard()
        
        // Setup:
        // Thermo: (0,0) -> (0,1)
        // Parity: (0,0) is Odd
        
        let thermoPath = [[0,0], [0,1]]
        let parity = "1" + String(repeating: "0", count: 80) // (0,0) is Odd
        
        // Define Rules
        let rules: [SudokuRule] = [
            .thermo(paths: [thermoPath]),
            .oddEven(parity: parity)
        ]
        
        // Pre-fill (0,1) with '4'
        board[0][1] = 4
        
        // Test Case 1: Passes Thermo (2 < 4) but Fails Parity (2 is Even)
        board[0][0] = 2
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Combined: 2 satisfies Thermo but fails Parity (Even)")
        
        // Test Case 2: Passes Parity (5 is Odd) but Fails Thermo (5 > 4)
        board[0][0] = 5
        XCTAssertFalse(validator.validate(board: board, rules: rules), "Combined: 5 satisfies Parity but fails Thermo (Greater than neighbor)")
        
        // Test Case 3: Passes Both (3 is Odd AND 3 < 4)
        board[0][0] = 3
        XCTAssertTrue(validator.validate(board: board, rules: rules), "Combined: 3 satisfies both Thermo and Parity")
    }

    // MARK: - Helpers
    
    static func emptyBoard() -> [[Int]] {
        return Array(repeating: Array(repeating: 0, count: 9), count: 9)
    }
}
#endif
