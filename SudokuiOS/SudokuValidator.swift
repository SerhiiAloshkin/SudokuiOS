import Foundation

enum SudokuRule {
    case classic
    case arrow([SudokuLevel.Arrow])
    case killer([SudokuLevel.Cage])
    case kropki(white: [SudokuLevel.KropkiDot], black: [SudokuLevel.KropkiDot], negativeConstraint: Bool)
    case oddEven(parity: String)
    case knight
    case king
    case nonConsecutive
    case sandwich(rows: [Int?], cols: [Int?])
    case thermo(paths: [[[Int]]])
    
    // Explicit mapping to the new Type Enum if needed, but 'SudokuRule' holds associated data.
    // We can keep this separate as it is the "Active Rule" description.
}

class SudokuValidator {
    
    func validate(board: [[Int]], rules: [SudokuRule]) -> Bool {
        for rule in rules {
            switch rule {
            case .classic:
                if !validateClassic(board) {
                    return false
                }
            case .arrow(let arrows):
                if !validateArrow(board, arrows: arrows) {
                    return false
                }
            case .killer(let cages):
                if !validateKiller(board, cages: cages) {
                    return false
                }
            case .kropki(let white, let black, let neg):
                if !validateKropki(board, white: white, black: black, negativeConstraint: neg) {
                    return false
                }
            case .oddEven(let parity):
                if !validateOddEven(board, parity: parity) {
                    return false
                }
            case .knight:
                if !validateKnight(board) {
                    return false
                }
            case .king:
                if !validateKing(board) {
                    return false
                }
            case .nonConsecutive:
                if !validateNonConsecutive(board) {
                    return false
                }
            case .sandwich(let rows, let cols):
                if !validateSandwich(board, rowClues: rows, colClues: cols) { return false }
            case .thermo(let paths):
                if !validateThermo(board, paths: paths) { return false }
            }
        }
        return true
    }
    
    // ... (existing helper methods)

    private func validateSandwich(_ board: [[Int]], rowClues: [Int?], colClues: [Int?]) -> Bool {
        // Validate Rows
        for (r, clue) in rowClues.enumerated() {
            guard let targetSum = clue, r < 9 else { continue }
            
            if let sum = calculateSandwichSum(board[r]) {
                if sum != targetSum { return false }
            } else {
                // partial board or missing 1/9?
                // If board is full/valid, 1 and 9 must exist.
                // If 1 or 9 are missing, we can't validate the sum yet.
                // Assuming validate() is called on potentially incomplete boards?
                // If it's a "move validator", we might skip.
                // But for "Game Complete" check, they must exist.
                // For this specific 'constraint' test, we assume we check validity if possible.
                // If 1 or 9 missing, we ignore? Or fail?
                // In strict Sudoku, 1 and 9 are required.
                // For simplicity: if 1 and 9 exist, check sum.
            }
        }
        
        // Validate Columns
        for (c, clue) in colClues.enumerated() {
            guard let targetSum = clue, c < 9 else { continue }
            
            let colValues = (0..<9).map { board[$0][c] }
            if let sum = calculateSandwichSum(colValues) {
                if sum != targetSum { return false }
            }
        }
        
        return true
    }
    
    private func calculateSandwichSum(_ cells: [Int]) -> Int? {
        guard let idx1 = cells.firstIndex(of: 1),
              let idx9 = cells.firstIndex(of: 9) else {
            return nil
        }
        
        let minIdx = min(idx1, idx9)
        let maxIdx = max(idx1, idx9)
        
        // Strictly between
        if maxIdx - minIdx <= 1 { return 0 }
        
        let range = (minIdx + 1)..<maxIdx
        let sum = range.reduce(0) { $0 + cells[$1] }
        return sum
    }

    private func validateNonConsecutive(_ board: [[Int]]) -> Bool {
        for r in 0..<9 {
            for c in 0..<9 {
                let val = board[r][c]
                if val == 0 { continue }
                
                // Check Right
                if c < 8 {
                    let rightVal = board[r][c + 1]
                    if rightVal != 0 && abs(val - rightVal) == 1 {
                        return false
                    }
                }
                // Check Down
                if r < 8 {
                    let downVal = board[r + 1][c]
                    if downVal != 0 && abs(val - downVal) == 1 {
                        return false
                    }
                }
            }
        }
        return true
    }
    
    private func validateClassic(_ board: [[Int]]) -> Bool {
        // Must be 9x9
        guard board.count == 9 else { return false }
        
        let fullMask: UInt16 = 0b1111111110 // 9 bits set (1 through 9)
        var colMasks = [UInt16](repeating: 0, count: 9)
        var boxMasks = [UInt16](repeating: 0, count: 9)
        
        for r in 0..<9 {
            var rowMask: UInt16 = 0
            let row = board[r]
            guard row.count == 9 else { return false }
            
            for c in 0..<9 {
                let val = row[c]
                if val < 1 || val > 9 { return false }
                
                let bit: UInt16 = 1 << val
                let boxIndex = (r / 3) * 3 + (c / 3)
                
                // If the bit is already set in any mask, there's a duplicate
                if (rowMask & bit) != 0 || (colMasks[c] & bit) != 0 || (boxMasks[boxIndex] & bit) != 0 {
                    return false
                }
                
                rowMask |= bit
                colMasks[c] |= bit
                boxMasks[boxIndex] |= bit
            }
            
            if rowMask != fullMask { return false }
        }
        
        // Rows are implicitly checked, just verify cols and boxes match fullMask
        for i in 0..<9 {
            if colMasks[i] != fullMask || boxMasks[i] != fullMask {
                return false
            }
        }
        
        return true
    }
    
    private func validateArrow(_ board: [[Int]], arrows: [SudokuLevel.Arrow]) -> Bool {
        for arrow in arrows {
            guard arrow.bulb.count == 2 else { continue }
            let bulbVal = board[arrow.bulb[0]][arrow.bulb[1]]
            
            // If bulb is empty (0), should we fail? Usually validator runs on full board.
            if bulbVal == 0 { return false }
            
            var sum = 0
            for coord in arrow.line {
                guard coord.count == 2 else { continue }
                let val = board[coord[0]][coord[1]]
                if val == 0 { return false }
                sum += val
            }
            
            if sum != bulbVal {
                return false
            }
        }
        return true
    }
    
    private func validateKiller(_ board: [[Int]], cages: [SudokuLevel.Cage]) -> Bool {
        for cage in cages {
            var sum = 0
            var values: [Int] = []
            
            for coord in cage.cells {
                guard coord.count == 2 else { continue }
                let val = board[coord[0]][coord[1]]
                
                // Fail if cell is empty (0)
                if val == 0 { return false }
                
                sum += val
                values.append(val)
            }
            
            // 1. Check Sum
            if sum != cage.sum {
                return false
            }
            
            // 2. Check Uniqueness (Killer Rule: No repeats in cage)
            if Set(values).count != values.count {
                return false
            }
        }
        return true
    }
    
    private func validateKropki(_ board: [[Int]], white: [SudokuLevel.KropkiDot], black: [SudokuLevel.KropkiDot], negativeConstraint: Bool) -> Bool {
        // 1. Validate Existing White Dots
        for dot in white {
             let v1 = board[dot.r1][dot.c1]
             let v2 = board[dot.r2][dot.c2]
             if v1 == 0 || v2 == 0 { return false }
             if abs(v1 - v2) != 1 { return false }
        }
        
        // 2. Validate Existing Black Dots
        for dot in black {
             let v1 = board[dot.r1][dot.c1]
             let v2 = board[dot.r2][dot.c2]
             if v1 == 0 || v2 == 0 { return false }
             if v1 != 2 * v2 && v2 != 2 * v1 { return false }
        }
        
        // 3. Negative Constraint: Check all adjacent pairs for MISSING dots
        if negativeConstraint {
            // Helper to check if a dot exists between two cells
            func hasDot(r1: Int, c1: Int, r2: Int, c2: Int) -> Bool {
                // Check White
                if white.contains(where: {
                    ($0.r1 == r1 && $0.c1 == c1 && $0.r2 == r2 && $0.c2 == c2) ||
                    ($0.r1 == r2 && $0.c1 == c2 && $0.r2 == r1 && $0.c2 == c1)
                }) { return true }
                
                // Check Black
                if black.contains(where: {
                    ($0.r1 == r1 && $0.c1 == c1 && $0.r2 == r2 && $0.c2 == c2) ||
                    ($0.r1 == r2 && $0.c1 == c2 && $0.r2 == r1 && $0.c2 == c1)
                }) { return true }
                
                return false
            }
            
            // Iterate all horizontal pairs
            for r in 0..<9 {
                for c in 0..<8 {
                     if !hasDot(r1: r, c1: c, r2: r, c2: c+1) {
                         let v1 = board[r][c]
                         let v2 = board[r][c+1]
                         if v1 != 0 && v2 != 0 {
                             // Check for violation (Diff 1 OR Ratio 1:2)
                             if abs(v1 - v2) == 1 { return false }
                             if v1 == 2 * v2 || v2 == 2 * v1 { return false }
                         }
                     }
                }
            }
            
            // Iterate all vertical pairs
            for r in 0..<8 {
                for c in 0..<9 {
                     if !hasDot(r1: r, c1: c, r2: r+1, c2: c) {
                         let v1 = board[r][c]
                         let v2 = board[r+1][c]
                         if v1 != 0 && v2 != 0 {
                             if abs(v1 - v2) == 1 { return false }
                             if v1 == 2 * v2 || v2 == 2 * v1 { return false }
                         }
                     }
                }
            }
        }
        
        return true
    }
    
    private func validateOddEven(_ board: [[Int]], parity: String) -> Bool {
        let parityChars = Array(parity)
        guard parityChars.count == 81 else { return true } // Safe to ignore if malformed.
        
        for r in 0..<9 {
            for c in 0..<9 {
                let index = r * 9 + c
                let char = parityChars[index]
                let val = board[r][c]
                
                if val == 0 { continue } // Skip empty cells
                
                if char == "1" { // Must be ODD
                    if val % 2 == 0 { return false }
                } else if char == "2" { // Must be EVEN
                    if val % 2 != 0 { return false }
                }
            }
        }
        return true
    }
    
    private func validateKnight(_ board: [[Int]]) -> Bool {
        let moves = [
            (-2, -1), (-2, 1), (-1, -2), (-1, 2),
            (1, -2), (1, 2), (2, -1), (2, 1)
        ]
        
        for r in 0..<9 {
            for c in 0..<9 {
                let val = board[r][c]
                if val == 0 { continue }
                
                for move in moves {
                    let nr = r + move.0
                    let nc = c + move.1
                    
                    if nr >= 0 && nr < 9 && nc >= 0 && nc < 9 {
                        if board[nr][nc] == val {
                            return false
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func validateKing(_ board: [[Int]]) -> Bool {
        // Check all 8 adjacent cells (including diagonals)
        for r in 0..<9 {
            for c in 0..<9 {
                let val = board[r][c]
                if val == 0 { continue }
                
                for dr in -1...1 {
                    for dc in -1...1 {
                        if dr == 0 && dc == 0 { continue } // Skip self
                        
                        let nr = r + dr
                        let nc = c + dc
                        
                        if nr >= 0 && nr < 9 && nc >= 0 && nc < 9 {
                            if board[nr][nc] == val {
                                return false
                            }
                        }
                    }
                }
            }
        }
        return true
    }

    private func validateThermo(_ board: [[Int]], paths: [[[Int]]]) -> Bool {
        for path in paths {
            var currentVal = -1
            
            for coord in path {
                guard coord.count == 2 else { continue }
                let r = coord[0]
                let c = coord[1]
                
                if r < 0 || r >= 9 || c < 0 || c >= 9 { continue }
                
                let val = board[r][c]
                
                if val == 0 {
                    // Stop checking this path at the first empty cell
                    break
                }
                
                // Strict Increase Check
                if currentVal != -1 {
                    if val <= currentVal {
                        return false
                    }
                }
                
                currentVal = val
            }
        }
        return true
    }
}
