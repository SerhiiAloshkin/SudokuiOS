import Foundation

struct SandwichMath {
    /// Returns all unique valid combinations of digits {2,3,4,5,6,7,8} that sum to the target.
    /// Results are sorted by:
    /// 1. Length (descending) - showing longest options first is often helpful.
    /// 2. Numerical order of the digits.
    static func getSandwichCombinations(for sum: Int) -> [[Int]] {
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
}
