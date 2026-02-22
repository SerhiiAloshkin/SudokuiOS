import XCTest
@testable import SudokuiOS

final class SandwichMathTests: XCTestCase {

    func testCombinationsFor10() {
        let result = SandwichMath.getSandwichCombinations(for: 10)
        
        // Expected:
        // Length 3: [2, 3, 5]
        // Length 2: [2, 8], [3, 7], [4, 6]
        
        XCTAssertEqual(result.count, 4)
        
        let expected = [
            [2, 3, 5],
            [2, 8],
            [3, 7],
            [4, 6]
        ]
        
        XCTAssertEqual(result, expected)
    }
    
    func testCombinationsFor35() {
        let result = SandwichMath.getSandwichCombinations(for: 35)
        
        // Max sum 2+3+4+5+6+7+8 = 35
        let expected = [[2, 3, 4, 5, 6, 7, 8]]
        
        XCTAssertEqual(result, expected)
    }
    
    func testExcludes1And9() {
        // Combinations for small numbers that might tempt usage of 1
        // e.g. 3 -> only [3] is valid. [1, 2] is invalid.
        let result = SandwichMath.getSandwichCombinations(for: 3)
        XCTAssertEqual(result, [[3]])
        
        // Check for NO 1 or 9 in a large set
        let result20 = SandwichMath.getSandwichCombinations(for: 20)
        for combo in result20 {
            XCTAssertFalse(combo.contains(1), "Combo should not contain 1: \(combo)")
            XCTAssertFalse(combo.contains(9), "Combo should not contain 9: \(combo)")
        }
    }
    
    func testZeroSum() {
        // Technically sandwich of 0 means side-by-side 1 and 9.
        // Since a sum of 0 is valid (adjacent 1 and 9), it corresponds to the empty set of digits.
        // So we expect one combination: the empty array.
        let result = SandwichMath.getSandwichCombinations(for: 0)
        XCTAssertEqual(result, [[]])
    }
    
    func testSorting() {
        // Sum 15
        // 3-digit: [2, 5, 8], [2, 6, 7], [3, 4, 8], [3, 5, 7], [4, 5, 6]
        // 2-digit: [7, 8]
        
        let result = SandwichMath.getSandwichCombinations(for: 15)
        
        // Check length ordering
        let lengths = result.map { $0.count }
        XCTAssertTrue(lengths == lengths.sorted(by: >), "Should be sorted by length descending")
        
        // Check numerical ordering for same lengths
        // [7, 8] should be last if it's the only 2-digit
        // The first few should be the 3-digits.
        
        if let first = result.first, let second = result.dropFirst().first {
             // Just specific check: [2, 5, 8] comes before [2, 6, 7]
             // Both start with 2. 5 < 6.
             XCTAssertEqual(first, [2, 5, 8])
             XCTAssertEqual(second, [2, 6, 7])
        }
    }
}
