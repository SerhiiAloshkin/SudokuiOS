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
    
    // MARK: - Non-Consecutive Filter Tests
    
    func testNonConsecutiveFilterSum8() {
        // Sum 8: combo [8] → sequence 1-8-9 has consecutive 8,9 → must be excluded
        let combos = SandwichMath.getSandwichCombinations(for: 8, rules: [.sandwich, .nonConsecutive])
        let flatCombos = combos.map { $0.sorted() }
        XCTAssertFalse(flatCombos.contains([8]), "[8] should be excluded: 1-8-9 has consecutive 8,9")
    }
    
    func testNonConsecutiveFilterSum9() {
        // Sum 9: combo [2,3,4] → no valid permutation between 1…9 → excluded
        let combos = SandwichMath.getSandwichCombinations(for: 9, rules: [.sandwich, .nonConsecutive])
        let flatCombos = combos.map { $0.sorted() }
        XCTAssertFalse(flatCombos.contains([2, 3, 4]), "[2,3,4] should be excluded: no valid non-consecutive permutation")
    }
    
    func testNonConsecutiveFilterSum9Valid() {
        // Sum 9: combo [2,7] → 1-7-2-9 is valid (diffs: 6,5,7) → included
        let combos = SandwichMath.getSandwichCombinations(for: 9, rules: [.sandwich, .nonConsecutive])
        let flatCombos = combos.map { $0.sorted() }
        XCTAssertTrue(flatCombos.contains([2, 7]), "[2,7] should be included: 1-7-2-9 is valid")
    }
    
    func testClassicRulesNoFiltering() {
        // With classic rules only, all combos should remain (no non-consecutive filtering)
        let combosClassic = SandwichMath.getSandwichCombinations(for: 8, rules: [.classic])
        let combosNoRules = SandwichMath.getSandwichCombinations(for: 8)
        XCTAssertEqual(combosClassic, combosNoRules, "Classic rules should not filter any combinations")
    }
    
    func testIsValidUnderNonConsecutive() {
        // Direct unit test of the validation function
        XCTAssertFalse(SandwichMath.isValidUnderNonConsecutive([8]), "[8] is invalid: always adjacent to 9")
        XCTAssertFalse(SandwichMath.isValidUnderNonConsecutive([2]), "[2] is invalid: always adjacent to 1")
        XCTAssertTrue(SandwichMath.isValidUnderNonConsecutive([3]), "[3] is valid: 1-3-9 has diffs 2,6")
        XCTAssertTrue(SandwichMath.isValidUnderNonConsecutive([]), "Empty combo is always valid")
        XCTAssertTrue(SandwichMath.isValidUnderNonConsecutive([4, 6]), "[4,6] is valid: 1-4-6-9 has diffs 3,2,3")
    }
}
