import XCTest
@testable import SudokuLogic

class SandwichMathTests: XCTestCase {
    
    func testGetSandwichCombinations() {
        // Sum 0: Should return [] (Actually 0 usually means adjacent 1/9, logic returns [[]] or [] depending on impl)
        // SandwichMath returns [] for sum 0 based on typical usage or logic.
        // Let's verify commonly known sums.
        
        // Sum 35 (2+3+4+5+6+7+8): Only one combo [2,3,4,5,6,7,8] in some order?
        // Wait, max sum is 35 (2..8). Dictionary lookup.
        let combos35 = SandwichMath.getSandwichCombinations(for: 35)
        XCTAssertFalse(combos35.isEmpty)
        // Check contents: must contain 2..8
        let first = combos35.first!
        XCTAssertEqual(first.count, 7)
        XCTAssertTrue(first.contains(2))
        XCTAssertTrue(first.contains(8))
        
        // Sum 5: [5] or [2,3]
        let combos5 = SandwichMath.getSandwichCombinations(for: 5)
        // Should have permutations of [5] and [2,3]
        // [5], [2,3], [3,2]
        let flatCombos = combos5.map { $0.sorted() }
        XCTAssertTrue(flatCombos.contains([5]))
        XCTAssertTrue(flatCombos.contains([2,3]))
    }
    
    func testPermutations() {
        let input = [1, 2, 3]
        let perms = SandwichMath.permute(input)
        XCTAssertEqual(perms.count, 6) // 3! = 6
        XCTAssertTrue(perms.contains([1, 2, 3]))
        XCTAssertTrue(perms.contains([3, 2, 1]))
    }
}
