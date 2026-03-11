import Foundation

struct PotentialHighlightCalculator {
    
    /// Calculates the set of restricted indices for a given digit.
    /// Restricted indices are those that are NOT basic conflicts but are logically impossible.
    static func calculatePotentials(
        board: [Int],
        digit: Int,
        isValid: (Int, Int) -> Bool // (digit, index) -> Bool
    ) -> Set<Int> {
        guard digit >= 1, digit <= 9 else { return [] }
        
        // 1. Base Potential Calculation
        var potentials: Set<Int> = []
        var basePotentials: Set<Int> = []
        for i in 0..<81 {
            if board[i] == 0 {
                if isValid(digit, i) {
                    potentials.insert(i)
                    basePotentials.insert(i)
                }
            }
        }
        
        // 2. Iterative Pruning (Intersection Removal)
        var changed = true
        var passes = 0
        while changed && passes < 10 {
            changed = false
            let countBefore = potentials.count
            
            // Rule 1: Pointing Logic (Box to Line)
            for boxIndex in 0..<9 {
                let boxIndices = getBoxIndices(boxIndex)
                let potentialsInBox = potentials.intersection(boxIndices)
                guard !potentialsInBox.isEmpty else { continue }
                
                // Check Row alignment
                let rows = Set(potentialsInBox.map { $0 / 9 })
                if rows.count == 1, let row = rows.first {
                    let rowIndices = getRowIndices(row).subtracting(boxIndices)
                    let before = potentials.count
                    potentials.subtract(rowIndices)
                    if potentials.count != before { changed = true }
                }
                
                // Check Column alignment
                let cols = Set(potentialsInBox.map { $0 % 9 })
                if cols.count == 1, let col = cols.first {
                    let colIndices = getColIndices(col).subtracting(boxIndices)
                    let before = potentials.count
                    potentials.subtract(colIndices)
                    if potentials.count != before { changed = true }
                }
            }
            
            // Rule 2: Box/Line Reduction (Line to Box)
            // Rows
            for row in 0..<9 {
                let rowIndices = getRowIndices(row)
                let potentialsInRow = potentials.intersection(rowIndices)
                guard !potentialsInRow.isEmpty else { continue }
                
                let boxes = Set(potentialsInRow.map { getBoxIndex(at: $0) })
                if boxes.count == 1, let box = boxes.first {
                    let boxIndices = getBoxIndices(box).subtracting(rowIndices)
                    let before = potentials.count
                    potentials.subtract(boxIndices)
                    if potentials.count != before { changed = true }
                }
            }
            
            // Columns
            for col in 0..<9 {
                let colIndices = getColIndices(col)
                let potentialsInCol = potentials.intersection(colIndices)
                guard !potentialsInCol.isEmpty else { continue }
                
                let boxes = Set(potentialsInCol.map { getBoxIndex(at: $0) })
                if boxes.count == 1, let box = boxes.first {
                    let boxIndices = getBoxIndices(box).subtracting(colIndices)
                    let before = potentials.count
                    potentials.subtract(boxIndices)
                    if potentials.count != before { changed = true }
                }
            }
            
            if potentials.count == countBefore { changed = false }
            passes += 1
        }
        
        // 3. Rule 3: Empty Box Contradiction Check
        let boxesWithDigit = Set((0..<81).filter { board[$0] == digit }.map { getBoxIndex(at: $0) })
        let boxesToWatch = Set(0..<9).subtracting(boxesWithDigit)
        
        var finalPotentials = Set<Int>()
        let boxMap = (0..<9).map { getBoxIndices($0) }
        
        for cell in potentials {
            let row = cell / 9
            let col = cell % 9
            let box = getBoxIndex(at: cell)
            
            var hasContradiction = false
            for boxToWatchIndex in boxesToWatch {
                if boxToWatchIndex == box { continue }
                
                let boxPotentialIndices = potentials.intersection(boxMap[boxToWatchIndex])
                let remainingInBox = boxPotentialIndices.filter { idx in
                    (idx / 9 != row) && (idx % 9 != col)
                }
                
                if remainingInBox.isEmpty {
                    hasContradiction = true
                    break
                }
            }
            
            if !hasContradiction {
                finalPotentials.insert(cell)
            }
        }
        
        // Restricted indices are those that were initially valid but were pruned
        return basePotentials.subtracting(finalPotentials)
    }
    
    // MARK: - Helpers
    
    private static func getBoxIndex(at index: Int) -> Int {
        let r = index / 9
        let c = index % 9
        return (r / 3) * 3 + (c / 3)
    }
    
    private static func getRowIndices(_ row: Int) -> Set<Int> {
        return Set((0..<9).map { row * 9 + $0 })
    }
    
    private static func getColIndices(_ col: Int) -> Set<Int> {
        return Set((0..<9).map { $0 * 9 + col })
    }
    
    private static func getBoxIndices(_ box: Int) -> Set<Int> {
        let startR = (box / 3) * 3
        let startC = (box % 3) * 3
        var indices: Set<Int> = []
        for r in startR..<startR+3 {
            for c in startC..<startC+3 {
                indices.insert(r * 9 + c)
            }
        }
        return indices
    }
}
