import XCTest
@testable import SudokuiOS

final class ArrowSudokuTests: XCTestCase {

    // 1. Test JSON Decoding
    func testArrowDecoding() throws {
        let json = """
        {
            "id": 5,
            "isLocked": false,
            "isSolved": false,
            "board": "052000000000000000000000000000000000000000000000000000000000000000000000000000000",
            "arrows": [
                {
                    "bulb": [0,0],
                    "line": [[0,1], [0,2]]
                }
            ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let level = try decoder.decode(SudokuLevel.self, from: json)
        
        XCTAssertNotNil(level.arrows)
        XCTAssertEqual(level.arrows?.count, 1)
        XCTAssertEqual(level.arrows?.first?.bulb, [0,0])
        XCTAssertEqual(level.arrows?.first?.line.count, 2)
    }
    
    // 2. Test Validator Logic
    func testArrowValidator() {
        let validator = SudokuValidator()
        
        // Mock a 9x9 board (mostly zeros for this test, but validator checks full classic rules too? 
        // No, we can test just the arrow rule if we invoke validateArrow privately or via mocked public interface if allowed.
        // But validate() checks ALL rules.
        // Let's assume we just want to test if the Arrow logic holds.
        // Warning: `validateClassic` expects a full valid board.
        // If we want to test JUST arrow, we might need to expose a helper or ensure board is classic-valid.
        // Or we can construct a board that IS classic valid.
        
        // Simpler: Just make a valid board and break the arrow rule, then fix it.
        var validBoard = [
            [5, 2, 3, 4, 1, 6, 7, 8, 9],
            [4, 6, 7, 8, 9, 3, 1, 2, 5],
            [8, 9, 1, 2, 5, 7, 3, 4, 6],
            [1, 3, 2, 5, 6, 8, 9, 7, 4],
            [6, 7, 4, 9, 3, 1, 5, 2, 8],
            [9, 5, 8, 7, 4, 2, 6, 1, 3],
            [2, 1, 6, 3, 8, 5, 4, 9, 7],
            [3, 4, 9, 1, 7, 4, 2, 6, 5], // row 7 error? (4 repeated). Fixed below.
            [7, 8, 5, 6, 2, 9, 8, 3, 1]  // row 8 error?
        ]
        // Actually, constructing a manual magic square is hard.
        // Let's modify SudokuValidator to only run Arrow rule for this test, if possible?
        // SudokuValidator.validate takes [SudokuRule]. We can pass just [.arrow].
        
        // Test Case: Bulb at [0,0] is 5. Line is [0,1]=2 and [0,2]=3. Sum 2+3=5. Valid.
        var testBoard = Array(repeating: Array(repeating: 1, count: 9), count: 9)
        testBoard[0][0] = 5
        testBoard[0][1] = 2
        testBoard[0][2] = 3
        
        let arrowRule = SudokuLevel.Arrow(bulb: [0,0], line: [[0,1], [0,2]])
        
        // Valid Case
        let isValid = validator.validate(board: testBoard, rules: [.arrow([arrowRule])])
        XCTAssertTrue(isValid, "5 = 2 + 3 should be valid")
        
        // Invalid Case
        testBoard[0][1] = 4 // Sum 4+3=7 != 5
        let isInvalid = validator.validate(board: testBoard, rules: [.arrow([arrowRule])])
        XCTAssertFalse(isInvalid, "5 != 4 + 3 should be invalid")
    }
    
    // 3. Test Coordinate Mapping Logic (Replicated from ArrowDrawingView)
    func testCoordinateMapping() {
        let width: CGFloat = 360
        let cellSize = width / 9
        let col = 7 // X axis
        let row = 2 // Y axis
        
        // Logic: x = (col + 0.5) * size
        let x = (CGFloat(col) + 0.5) * cellSize
        let y = (CGFloat(row) + 0.5) * cellSize
        
        // Expected: (7.5 * 40, 2.5 * 40) -> (300, 100)
        
        XCTAssertEqual(cellSize, 40)
        XCTAssertEqual(x, 300)
        XCTAssertEqual(y, 100)
    }

    // 4. Test Specific Level 5 Decoding
    func testLevel5ArrowDecoding() throws {
        let json = """
        {
            "id": 5,
            "isLocked": false,
            "isSolved": false,
            "difficulty": "Easy",
            "ruleType": "arrow",
            "board": "000...",
            "arrows": [
                {
                    "bulb": [2, 7],
                    "line": [[3, 7], [3, 6]]
                }
            ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let level = try decoder.decode(SudokuLevel.self, from: json)
        
        XCTAssertNotNil(level.arrows)
        XCTAssertEqual(level.arrows?.count, 1)
        
        let arrow = level.arrows!.first!
        XCTAssertEqual(arrow.bulb, [2, 7]) // Row 2, Col 7
        XCTAssertEqual(arrow.line.count, 2)
        XCTAssertEqual(arrow.line[0], [3, 7])
    }
}
