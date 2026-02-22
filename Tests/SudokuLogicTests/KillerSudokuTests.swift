import XCTest
@testable import SudokuiOS

final class KillerSudokuTests: XCTestCase {

    // 1. Test JSON Decoding
    func testKillerDecoding() throws {
        let json = """
        {
            "id": 6,
            "isLocked": false,
            "isSolved": false,
            "board": "000000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "cages": [
                {
                    "sum": 10,
                    "cells": [[0,0], [0,1]]
                },
                {
                    "sum": 15,
                    "cells": [[1,0], [1,1], [1,2]]
                }
            ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let level = try decoder.decode(SudokuLevel.self, from: json)
        
        XCTAssertNotNil(level.cages)
        XCTAssertEqual(level.cages?.count, 2)
        
        let firstCage = level.cages!.first!
        XCTAssertEqual(firstCage.sum, 10)
        XCTAssertEqual(firstCage.cells.count, 2)
        XCTAssertEqual(firstCage.cells[0], [0,0])
    }
    
    // 2. Test Top-Left Finder Logic
    func testTopLeftFinder() {
        // Square Cage
        let cage1 = SudokuLevel.Cage(sum: 10, cells: [[2,2], [2,3], [3,2], [3,3]])
        XCTAssertEqual(cage1.topLeft, [2,2])
        
        // L-Shape Cage (Top-Left is corner)
        // [1,1] [1,2]
        // [2,1]
        let cage2 = SudokuLevel.Cage(sum: 10, cells: [[1,1], [1,2], [2,1]])
        XCTAssertEqual(cage2.topLeft, [1,1])
        
        // L-Shape Cage (Top-Left is "top" even if "left" is lower?)
        // Logic: specific implementation sorts by Row then Col.
        // If cells are [1,2] and [2,1], Row 1 is min. So [1,2].
        // Is this correct for "Visual Label"?
        // Usually label goes in top-most, if tie then left-most.
        // Let's verify standard rules: Label is top-left corner.
        // If shape is:
        //   [ ]  <- (1,3)
        // [ ]    <- (2,2)
        // Top-most is (1,3).
        let cage3 = SudokuLevel.Cage(sum: 10, cells: [[1,3], [2,2]])
        XCTAssertEqual(cage3.topLeft, [1,3])
        
        // Unsorted input
        let cage4 = SudokuLevel.Cage(sum: 10, cells: [[5,5], [4,4]])
        XCTAssertEqual(cage4.topLeft, [4,4])
    }
    
    // 3. Test Validator Logic
    func testKillerValidator() {
        let validator = SudokuValidator()
        
        // Mock Board (partial fill is okay if we only validate the cells in question)
        var testBoard = Array(repeating: Array(repeating: 0, count: 9), count: 9)
        
        let cage = SudokuLevel.Cage(sum: 11, cells: [[5,5], [5,6]])
        
        // Case A: Valid (5 + 6 = 11)
        testBoard[5][5] = 5
        testBoard[5][6] = 6
        
        let isValid = validator.validate(board: testBoard, rules: [.killer([cage])])
        XCTAssertTrue(isValid, "5 + 6 = 11 should be valid")
        
        // Case B: Invalid Sum (5 + 5 = 10 != 11)
        testBoard[5][6] = 5
        
        // Note: This ALSO violates Uniqueness in cage (5, 5).
        // Validator checks both.
        let isInvalidSumAndUnique = validator.validate(board: testBoard, rules: [.killer([cage])])
        XCTAssertFalse(isInvalidSumAndUnique, "5 + 5 != 11 and not unique")
        
        // Case C: Invalid Sum, Unique (5 + 4 = 9 != 11)
        testBoard[5][6] = 4
        let isInvalidSum = validator.validate(board: testBoard, rules: [.killer([cage])])
        XCTAssertFalse(isInvalidSum, "5 + 4 != 11")
        
        // Case D: Valid Sum, Invalid Unique? (Impossible for 2 cells if sum is odd? No, 11 is odd. 5+6 ok.
        // If Sum 10, [5,5] -> Check Uniqueness specifically
        let cageUnique = SudokuLevel.Cage(sum: 10, cells: [[0,0], [0,1]])
        testBoard[0][0] = 5
        testBoard[0][1] = 5
        let isRepeated = validator.validate(board: testBoard, rules: [.killer([cageUnique])])
        XCTAssertFalse(isRepeated, "5 + 5 = 10 is correct sum, but repeats are invalid in Killer")
    }
}
