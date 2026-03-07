import Foundation

struct SandwichMath {
    /// Returns all unique valid combinations of digits {2,3,4,5,6,7,8} that sum to the target.
    /// Results are sorted by:
    /// 1. Length (descending) - showing longest options first is often helpful.
    /// 2. Numerical order of the digits.
    static func getSandwichCombinations(for sum: Int) -> [[Int]] {
        return getSandwichCombinations(for: sum, rules: [])
    }
    
    /// Returns all unique valid combinations of digits {2,3,4,5,6,7,8} that sum to the target,
    /// filtered by the active rules. When `nonConsecutive` is present in `rules`, combinations
    /// that have no valid ordering between the 1/9 boundaries are excluded.
    static func getSandwichCombinations(for sum: Int, rules: [SudokuRuleType]) -> [[Int]] {
        // Valid digits in a sandwich are 2-8 (since 1 and 9 are the crusts)
        let candidates = [2, 3, 4, 5, 6, 7, 8]
        var results: [[Int]] = []
        
        // Helper for recursion
        func findCombinations(target: Int, current: [Int], startIndex: Int) {
            if target == 0 {
                // Found a valid combination
                // Sort the numbers within the combination for consistency (though inputs are sorted)
                results.append(current.sorted())
                return
            }
            
            if target < 0 {
                return
            }
            
            for i in startIndex..<candidates.count {
                let num = candidates[i]
                
                // If this number exceeds remaining target, no point continuing since candidates are sorted
                if num > target {
                    break
                }
                
                var next = current
                next.append(num)
                findCombinations(target: target - num, current: next, startIndex: i + 1)
            }
        }
        
        findCombinations(target: sum, current: [], startIndex: 0)
        
        // Apply non-consecutive filter if the rule is active
        if rules.contains(.nonConsecutive) {
            results = results.filter { isValidUnderNonConsecutive($0) }
        }
        
        // Sort results:
        // 1. Length Descending
        // 2. Element-wise ascending
        results.sort { (a, b) -> Bool in
            if a.count != b.count {
                return a.count > b.count
            }
            
            // Same length, sort lexicographically
            for (numA, numB) in zip(a, b) {
                if numA != numB {
                    return numA < numB
                }
            }
            return false
        }
        
        return results
    }
    
    // MARK: - Non-Consecutive Validation
    
    /// Checks if at least one permutation of `combo` can be placed between the sandwich
    /// boundaries (1 and 9) without any two adjacent cells having consecutive values.
    /// The full sequence checked is [1, ...perm..., 9] and [9, ...perm..., 1].
    static func isValidUnderNonConsecutive(_ combo: [Int]) -> Bool {
        guard !combo.isEmpty else { return true } // Empty combo (sum 0) is always valid
        
        let perms = permute(combo)
        
        for perm in perms {
            // Check with boundaries [1, ...perm..., 9]
            if isNonConsecutiveSequenceValid(boundary1: 1, inner: perm, boundary2: 9) {
                return true
            }
            // Check with boundaries [9, ...perm..., 1]
            if isNonConsecutiveSequenceValid(boundary1: 9, inner: perm, boundary2: 1) {
                return true
            }
        }
        
        return false
    }
    
    /// Checks that no two adjacent elements in the sequence [boundary1, inner..., boundary2]
    /// have an absolute difference of 1.
    private static func isNonConsecutiveSequenceValid(boundary1: Int, inner: [Int], boundary2: Int) -> Bool {
        let sequence = [boundary1] + inner + [boundary2]
        for i in 0..<(sequence.count - 1) {
            if abs(sequence[i] - sequence[i + 1]) == 1 {
                return false
            }
        }
        return true
    }
    
    // MARK: - Permutation Helper
    
    /// Generates all permutations of the given array.
    /// Safe for small arrays (max 7 elements = 5040 permutations).
    static func permute(_ array: [Int]) -> [[Int]] {
        if array.count <= 1 { return [array] }
        
        var results: [[Int]] = []
        var arr = array
        
        func generate(_ n: Int) {
            if n == 1 {
                results.append(arr)
                return
            }
            for i in 0..<n {
                generate(n - 1)
                // Swap: if n is even, swap i-th with last; if odd, swap first with last
                if n % 2 == 0 {
                    arr.swapAt(i, n - 1)
                } else {
                    arr.swapAt(0, n - 1)
                }
            }
        }
        
        generate(arr.count)
        return results
    }
}
