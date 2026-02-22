import Foundation

struct PointingPairsSolver {
    
    /// Identifies cells that should be excluded from potential highlights due to Pointing Pairs/Triples.
    ///
    /// - Parameters:
    ///   - board: The current sudoku board as a string of 81 characters.
    ///   - digit: The currently selected digit (1-9).
    /// - Returns: A Set of indices that should be restricted (i.e., NOT highlighted).
    static func getPointedRestrictions(
        board: String,
        digit: Int,
        parityString: String? = nil,
        ruleType: SudokuRuleType = .classic,
        whiteDots: [SudokuLevel.KropkiDot]? = nil,
        blackDots: [SudokuLevel.KropkiDot]? = nil,
        negativeConstraint: Bool = false
    ) -> Set<Int> {
        var restrictedIndices: Set<Int> = []
        var changed = true
        
        // Safety Break (though monotonic growth guarantees termination in finite steps)
        var passes = 0
        while changed && passes < 20 {
            changed = false
            let newRestrictions = runPass(
                board: board,
                digit: digit,
                currentRestrictions: restrictedIndices,
                parityString: parityString,
                ruleType: ruleType,
                whiteDots: whiteDots,
                blackDots: blackDots,
                negativeConstraint: negativeConstraint
            )
            
            let diff = newRestrictions.subtracting(restrictedIndices)
            if !diff.isEmpty {
                restrictedIndices.formUnion(diff)
                changed = true
            }
            passes += 1
        }
        
        return restrictedIndices
    }
    
    private static func runPass(
        board: String,
        digit: Int,
        currentRestrictions: Set<Int>,
        parityString: String?,
        ruleType: SudokuRuleType,
        whiteDots: [SudokuLevel.KropkiDot]?,
        blackDots: [SudokuLevel.KropkiDot]?,
        negativeConstraint: Bool
    ) -> Set<Int> {
        guard digit >= 1, digit <= 9 else { return [] }
        var restrictedIndices: Set<Int> = []
        
        let grid = Array(board)
        guard grid.count == 81 else { return [] }
        
        // Pre-parse board into [Int] for fast lookups (done once per pass)
        var intGrid = [Int](repeating: 0, count: 81)
        for i in 0..<81 {
            intGrid[i] = grid[i].wholeNumberValue ?? 0
        }
        
        // Helper to check basic validity (Row, Col, Box) for a candidate
        func isValidCandidate(at index: Int) -> Bool {
            // Must be empty
            if intGrid[index] != 0 { return false }
            
            // Must NOT be already restricted (Iterative Logic)
            if currentRestrictions.contains(index) { return false }
            
            // Check Parity Constraint (if exists)
            if let parity = parityString, index < parity.count {
                let pChar = parity[parity.index(parity.startIndex, offsetBy: index)]
                if pChar == "1" && digit % 2 == 0 { return false }
                if pChar == "2" && digit % 2 != 0 { return false }
            }
            
            // KNIGHT Constraint
            if ruleType == .knight {
                 let r = index / 9; let c = index % 9
                 for move in HighlightManager.knightOffsets {
                     let nr = r + move.0; let nc = c + move.1
                     if nr >= 0 && nr < 9 && nc >= 0 && nc < 9 {
                         if intGrid[nr * 9 + nc] == digit { return false }
                     }
                 }
            }
            
            // KING Constraint
            if ruleType == .king {
                 let r = index / 9; let c = index % 9
                 for move in HighlightManager.kingOffsets {
                     let nr = r + move.0; let nc = c + move.1
                     if nr >= 0 && nr < 9 && nc >= 0 && nc < 9 {
                         if intGrid[nr * 9 + nc] == digit { return false }
                     }
                 }
            }
            
            // KROPKI Constraint
            if ruleType == .kropki {
                let r = index / 9; let c = index % 9
                let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]
                
                for move in neighbors {
                    let nr = r + move.0; let nc = c + move.1
                    if nr >= 0 && nr < 9 && nc >= 0 && nc < 9 {
                        let ni = nr * 9 + nc
                        let nVal = intGrid[ni]
                        
                        // Only check against placed numbers
                        if nVal > 0 {
                            // Check connections
                            var isWhite = false
                            var isBlack = false
                            
                            // Check White
                            if let wDots = whiteDots {
                                for dot in wDots {
                                    if (dot.r1 == r && dot.c1 == c && dot.r2 == nr && dot.c2 == nc) ||
                                       (dot.r1 == nr && dot.c1 == nc && dot.r2 == r && dot.c2 == c) {
                                        isWhite = true
                                        break
                                    }
                                }
                            }
                            
                            // Check Black
                            if let bDots = blackDots {
                                for dot in bDots {
                                    if (dot.r1 == r && dot.c1 == c && dot.r2 == nr && dot.c2 == nc) ||
                                       (dot.r1 == nr && dot.c1 == nc && dot.r2 == r && dot.c2 == c) {
                                        isBlack = true
                                        break
                                    }
                                }
                            }
                            
                            if isWhite {
                                if abs(digit - nVal) != 1 { return false }
                            }
                            
                            if isBlack {
                                if digit != nVal * 2 && nVal != digit * 2 { return false }
                            }
                            
                            if negativeConstraint && !isWhite && !isBlack {
                                if abs(digit - nVal) == 1 { return false }
                                if digit == nVal * 2 || nVal == digit * 2 { return false }
                            }
                        }
                    }
                }
            }
            
            let row = index / 9
            let col = index % 9
            let boxRow = row / 3
            let boxCol = col / 3
            
            // Check Row/Col/Box collision using targeted scans instead of 81-cell loop
            // Check Row
            for c in 0..<9 {
                let i = row * 9 + c
                if i == index { continue }
                if intGrid[i] == digit { return false }
            }
            // Check Col
            for r in 0..<9 {
                let i = r * 9 + col
                if i == index { continue }
                if intGrid[i] == digit { return false }
            }
            // Check Box
            let boxStartR = boxRow * 3
            let boxStartC = boxCol * 3
            for r in boxStartR..<(boxStartR + 3) {
                for c in boxStartC..<(boxStartC + 3) {
                    let i = r * 9 + c
                    if i == index { continue }
                    if intGrid[i] == digit { return false }
                }
            }
            return true
        }
        
        // Analyze each Box (0..8)
        for boxIndex in 0..<9 {
            // Get all candidate indices in this box
            let boxStartRow = (boxIndex / 3) * 3
            let boxStartCol = (boxIndex % 3) * 3
            
            var candidates: [Int] = []
            
            for r in boxStartRow..<(boxStartRow + 3) {
                for c in boxStartCol..<(boxStartCol + 3) {
                    let index = r * 9 + c
                    if isValidCandidate(at: index) {
                        candidates.append(index)
                    }
                }
            }
            
            // Apply Pointing Pairs Logic
            if candidates.count >= 1 && candidates.count <= 3 {
                // Check Row Alignment
                let firstRow = candidates[0] / 9
                if candidates.allSatisfy({ $0 / 9 == firstRow }) {
                    for c in 0..<9 {
                        let idx = firstRow * 9 + c
                        let idxBox = (firstRow / 3) * 3 + (c / 3)
                        if idxBox != boxIndex && intGrid[idx] == 0 {
                             restrictedIndices.insert(idx)
                        }
                    }
                }
                
                // Check Col Alignment
                let firstCol = candidates[0] % 9
                if candidates.allSatisfy({ $0 % 9 == firstCol }) {
                    for r in 0..<9 {
                        let idx = r * 9 + firstCol
                        let idxBox = (r / 3) * 3 + (firstCol / 3)
                        if idxBox != boxIndex && intGrid[idx] == 0 {
                             restrictedIndices.insert(idx)
                        }
                    }
                }
            }
        }
        
        // 2. Box/Line Reduction (Claiming) (Line -> Box)
        // Check Rows (0..8)
        for row in 0..<9 {
            var colCandidates: [Int] = []
            for col in 0..<9 {
                let idx = row * 9 + col
                if isValidCandidate(at: idx) {
                    colCandidates.append(col)
                }
            }
            
            if !colCandidates.isEmpty {
                let firstCol = colCandidates[0]
                let boxColStart = (firstCol / 3) * 3
                if colCandidates.allSatisfy({ ($0 / 3) * 3 == boxColStart }) {
                    let boxRowStart = (row / 3) * 3
                    for r in boxRowStart..<(boxRowStart + 3) {
                        for c in boxColStart..<(boxColStart + 3) {
                            if r == row { continue }
                            let idx = r * 9 + c
                            if intGrid[idx] == 0 {
                                restrictedIndices.insert(idx)
                            }
                        }
                    }
                }
            }
        }
        
        // Check Cols (0..8)
        for col in 0..<9 {
            var rowCandidates: [Int] = []
            for row in 0..<9 {
                let idx = row * 9 + col
                if isValidCandidate(at: idx) {
                    rowCandidates.append(row)
                }
            }
            
            if !rowCandidates.isEmpty {
                let firstRow = rowCandidates[0]
                let boxRowStart = (firstRow / 3) * 3
                if rowCandidates.allSatisfy({ ($0 / 3) * 3 == boxRowStart }) {
                    let boxColStart = (col / 3) * 3
                    for r in boxRowStart..<(boxRowStart + 3) {
                        for c in boxColStart..<(boxColStart + 3) {
                            if c == col { continue }
                            let idx = r * 9 + c
                            if intGrid[idx] == 0 {
                                restrictedIndices.insert(idx)
                            }
                        }
                    }
                }
            }
        }
        
        return restrictedIndices
    }
}

struct SandwichSolver {
    
    /// Identifies cells that should be excluded for 1 or 9 because they violate Sandwich Sum constraints.
    static func getSandwichRestrictions(board: String, digit: Int, rowClues: [Int]?, colClues: [Int]?) -> Set<Int> {
        // Only applies to Crusts (1 and 9)
        guard digit == 1 || digit == 9 else { return [] }
        
        let otherCrust = (digit == 1) ? 9 : 1
        var restrictedIndices: Set<Int> = []
        let grid = Array(board)
        guard grid.count == 81 else { return [] }
        
        // Helper to get value
        func val(_ idx: Int) -> Int {
            Int(String(grid[idx])) ?? 0
        }
        
        // Check Rows
        if let clues = rowClues {
            for row in 0..<9 {
                let clue = clues[row]
                guard clue >= 0 else { continue } // Ignore -1 or empty clues
                
                // Find candidates for 'digit' in this row
                var candidates: [Int] = []
                var fixedOtherIndex: Int? = nil
                
                for col in 0..<9 {
                    let idx = row * 9 + col
                    let v = val(idx)
                    if v == digit { 
                        // Already placed 'digit'? Then potential HIGHLIGHTING logic implies we are checking EMPTY cells for *placement* hints?
                        // Or if 'digit' is selected, we are highlighting where it CAN go.
                        // If it's already on board, we usually don't highlight potentials elsewhere for validity unless it's the wrong placement.
                        // But let's assume valid candidates are empty cells.
                    } else if v == 0 {
                        candidates.append(idx)
                    } else if v == otherCrust {
                        fixedOtherIndex = idx
                    }
                }
                
                // For each candidate, check if it satisfies the row clue
                for idx in candidates {
                    var isPossible = false
                    
                    if let otherIdx = fixedOtherIndex {
                        // Case A: Other crust is fixed
                        if checkSandwich(idx1: idx, idx2: otherIdx, clue: clue, grid: grid) {
                            isPossible = true
                        }
                    } else {
                        // Case B: Other crust is NOT fixed. 
                        // Must find at least one valid candidate for otherCrust in this row
                        for col2 in 0..<9 {
                            let idx2 = row * 9 + col2
                            if idx2 == idx { continue }
                            let v = val(idx2)
                            if v == 0 {
                                // Potential other crust
                                // CRITICAL FIX: Check if 'otherCrust' can actually go here (Row/Col/Box)
                                // We are in a ROW check, so Row is inherently safe (empty).
                                // Must check Col and Box for 'otherCrust'.
                                if isValid(board: grid, index: idx2, value: otherCrust) {
                                    if checkSandwich(idx1: idx, idx2: idx2, clue: clue, grid: grid) {
                                        isPossible = true
                                        break
                                    }
                                }
                            }
                        }
                    }
                    
                    if !isPossible {
                        restrictedIndices.insert(idx)
                    }
                }
            }
        }
        
        // Check Cols
        if let clues = colClues {
            for col in 0..<9 {
                let clue = clues[col]
                guard clue >= 0 else { continue }
                
                var candidates: [Int] = []
                var fixedOtherIndex: Int? = nil
                
                for row in 0..<9 {
                    let idx = row * 9 + col
                    let v = val(idx)
                    if v == 0 {
                        candidates.append(idx)
                    } else if v == otherCrust {
                        fixedOtherIndex = idx
                    }
                }
                
                for idx in candidates {
                    var isPossible = false
                    
                    if let otherIdx = fixedOtherIndex {
                        if checkSandwich(idx1: idx, idx2: otherIdx, clue: clue, grid: grid) {
                            isPossible = true
                        }
                    } else {
                        for row2 in 0..<9 {
                            let idx2 = row2 * 9 + col
                            if idx2 == idx { continue }
                            if val(idx2) == 0 {
                                // Check valid placement for otherCrust
                                if isValid(board: grid, index: idx2, value: otherCrust) {
                                    if checkSandwich(idx1: idx, idx2: idx2, clue: clue, grid: grid) {
                                        isPossible = true
                                        break
                                    }
                                }
                            }
                        }
                    }
                    
                    if !isPossible {
                        restrictedIndices.insert(idx)
                    }
                }
            }
        }
        
        return restrictedIndices
    }
    
    /// Checks if a value can be placed at index without violating basic rules (Row, Col, Box)
    /// Intended for validating the *partner* crust position.
    static func isValid(board: [Character], index: Int, value: Int) -> Bool {
        let row = index / 9
        let col = index % 9
        let boxRow = row / 3
        let boxCol = col / 3
        
        for i in 0..<81 {
            if i == index { continue }
            let char = board[i]
            if char == "0" { continue }
            guard let v = Int(String(char)) else { continue }
            
            if v == value {
                let r = i / 9
                let c = i % 9
                let br = r / 3
                let bc = c / 3
                
                if r == row || c == col || (br == boxRow && bc == boxCol) {
                    return false
                }
            }
        }
        return true
    }
    
    // Checks if the range between idx1 and idx2 allows for the given clue sum
    static func checkSandwich(idx1: Int, idx2: Int, clue: Int, grid: [Character]) -> Bool {
        // Determine range cells
        // Are they in same row?
        let r1 = idx1 / 9; let c1 = idx1 % 9
        let r2 = idx2 / 9; let c2 = idx2 % 9
        
        var cellsInBetween: [Int] = []
        
        if r1 == r2 {
            // Row sandwich
            let start = min(c1, c2) + 1
            let end = max(c1, c2) - 1
            if start <= end {
                for c in start...end {
                    cellsInBetween.append(r1 * 9 + c)
                }
            }
        } else if c1 == c2 {
            // Col sandwich
            let start = min(r1, r2) + 1
            let end = max(r1, r2) - 1
            if start <= end {
                for r in start...end {
                    cellsInBetween.append(r * 9 + c1)
                }
            }
        } else {
            return false // Should not happen given logic
        }
        
        var currentSum = 0
        var hasEmpties = false
        
        for idx in cellsInBetween {
            let char = grid[idx]
            if char == "0" {
                hasEmpties = true
            } else {
                guard let v = Int(String(char)) else { continue }
                currentSum += v
            }
        }
        
        // Constraint 1: Sum of already fixed numbers must not exceed clue
        if currentSum > clue { return false }
        
        // Constraint 2: If no empties, sum must exactly match
        if !hasEmpties && currentSum != clue { return false }
        
        return true
    }
}
