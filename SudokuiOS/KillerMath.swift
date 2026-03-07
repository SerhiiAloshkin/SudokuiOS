import Foundation

struct KillerMath {
    /// Returns all valid combinations of unique digits {1...9} that sum to the target
    /// for a cage of a specific size.
    static func getCombinations(sum: Int, count: Int, rules: [SudokuRuleType], cageCells: [[Int]]? = nil) -> [[Int]] {
        var results = generateCombinations(target: sum, count: count, startIndex: 1)
        
        if rules.contains(.nonConsecutive), let cageCells = cageCells, !cageCells.isEmpty {
            results = results.filter { isValidUnderNonConsecutive(combo: $0, cageCells: cageCells) }
        }
        
        // Sort results:
        // 1. Element-wise ascending
        results.sort { (a, b) -> Bool in
            for (numA, numB) in zip(a, b) {
                if numA != numB {
                    return numA < numB
                }
            }
            return a.count < b.count
        }
        
        return results
    }
    
    private static func generateCombinations(target: Int, count: Int, startIndex: Int) -> [[Int]] {
        if count == 1 {
            if target >= startIndex && target <= 9 {
                return [[target]]
            }
            return []
        }
        
        var results: [[Int]] = []
        // We need at least 'count' digits, so max digit to try is target - sum of remaining min digits
        // Sum of next (count-1) digits starting from i+1 is (i+1) + (i+2) + ...
        for i in startIndex...9 {
            let remainingCount = count - 1
            let minRemainingSum = (remainingCount * (i + 1 + i + remainingCount)) / 2
            if i + minRemainingSum > target { break }
            
            let subCombos = generateCombinations(target: target - i, count: remainingCount, startIndex: i + 1)
            for var combo in subCombos {
                combo.insert(i, at: 0)
                results.append(combo)
            }
        }
        return results
    }
    
    // MARK: - Non-Consecutive Validation
    
    /// Checks if there exists at least one assignment of the digits in `combo` to the `cageCells`
    /// such that no two adjacent cells (orthogonally) have consecutive digits.
    static func isValidUnderNonConsecutive(combo: [Int], cageCells: [[Int]]) -> Bool {
        guard combo.count == cageCells.count else { return false }
        
        // 1. Build adjacency list for cage cells
        var adjacency: [[Int]] = Array(repeating: [], count: cageCells.count)
        for i in 0..<cageCells.count {
            for j in i+1..<cageCells.count {
                let cell1 = cageCells[i]
                let cell2 = cageCells[j]
                if abs(cell1[0] - cell2[0]) + abs(cell1[1] - cell2[1]) == 1 {
                    adjacency[i].append(j)
                    adjacency[j].append(i)
                }
            }
        }
        
        // 2. Backtracking to find a valid assignment
        var assignment = [Int?](repeating: nil, count: cageCells.count)
        
        func canPlace(digit: Int, at cellIndex: Int) -> Bool {
            for neighbor in adjacency[cellIndex] {
                if let assignedDigit = assignment[neighbor] {
                    if abs(assignedDigit - digit) == 1 {
                        return false
                    }
                }
            }
            return true
        }
        
        func solve(cellIdx: Int, availableDigits: [Int]) -> Bool {
            if cellIdx == cageCells.count {
                return true
            }
            
            for (i, digit) in availableDigits.enumerated() {
                if canPlace(digit: digit, at: cellIdx) {
                    assignment[cellIdx] = digit
                    var nextDigits = availableDigits
                    nextDigits.remove(at: i)
                    if solve(cellIdx: cellIdx + 1, availableDigits: nextDigits) {
                        return true
                    }
                    assignment[cellIdx] = nil // Backtrack
                }
            }
            return false
        }
        
        return solve(cellIdx: 0, availableDigits: combo)
    }
}
