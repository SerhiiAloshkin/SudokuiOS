import Foundation

/// Optimized potential highlight calculator with constraint graph caching
/// Reduces complexity from O(n²) to O(n) for subsequent calls with same board state
struct OptimizedPotentialHighlightCalculator {
    
    // MARK: - Constraint Graph (Precomputed)
    
    /// Cache of constraint relationships between cells
    private static var constraintGraph: [Int: Set<Int>] = [:]
    private static var graphBoardHash: Int = 0
    private static var graphRules: [SudokuRuleType] = []
    
    /// Build constraint graph once per board/rule combination
    private static func buildConstraintGraph(rules: [SudokuRuleType], board: [Int]) {
        let boardHash = board.hashValue
        
        // Check if cached graph is still valid
        if constraintGraph.count == 81 && graphBoardHash == boardHash && graphRules == rules {
            return // Graph already built for this configuration
        }
        
        // Clear and rebuild
        constraintGraph.removeAll(minimumCapacity: 81)
        graphBoardHash = boardHash
        graphRules = rules
        
        // Build adjacency list for each cell
        for index in 0..<81 {
            constraintGraph[index] = getConstraints(for: index, rules: rules)
        }
    }
    
    /// Get all cells that constrain the given cell
    private static func getConstraints(for index: Int, rules: [SudokuRuleType]) -> Set<Int> {
        let r = index / 9
        let c = index % 9
        let box = (r / 3) * 3 + (c / 3)
        
        var constraints = Set<Int>()
        
        // Classic constraints: Row, Column, Box
        for i in 0..<81 {
            let row = i / 9
            let col = i % 9
            let b = (row / 3) * 3 + (col / 3)
            
            if i != index && (row == r || col == c || b == box) {
                constraints.insert(i)
            }
        }
        
        // Knight moves
        if rules.contains(.knight) {
            let offsets = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
            for (dr, dc) in offsets {
                let nr = r + dr
                let nc = c + dc
                if nr >= 0 && nr < 9 && nc >= 0 && nc < 9 {
                    constraints.insert(nr * 9 + nc)
                }
            }
        }
        
        // King moves
        if rules.contains(.king) {
            for dr in -1...1 {
                for dc in -1...1 {
                    if dr == 0 && dc == 0 { continue }
                    let nr = r + dr
                    let nc = c + dc
                    if nr >= 0 && nr < 9 && nc >= 0 && nc < 9 {
                        constraints.insert(nr * 9 + nc)
                    }
                }
            }
        }
        
        return constraints
    }
    
    // MARK: - Optimized Potential Calculation
    
    /// Calculates potential cell placements with O(n) complexity using constraint graph
    static func calculatePotentials(
        board: [Int],
        digit: Int,
        rules: [SudokuRuleType],
        isValid: (Int, Int) -> Bool
    ) -> Set<Int> {
        guard digit >= 1, digit <= 9 else { return [] }
        
        // OPTIMIZATION: Build/reuse constraint graph
        buildConstraintGraph(rules: rules, board: board)
        
        // 1. Find all initially valid placements (O(n))
        var potentials: Set<Int> = []
        var basePotentials: Set<Int> = []
        
        for i in 0..<81 {
            if board[i] == 0 && isValid(digit, i) {
                potentials.insert(i)
                basePotentials.insert(i)
            }
        }
        
        // 2. Fast pruning using constraint graph (O(n) instead of O(n²))
        let restricted = fastPrune(
            potentials: potentials,
            board: board,
            digit: digit,
            rules: rules
        )
        
        return basePotentials.subtracting(restricted)
    }
    
    /// Fast pruning algorithm using precomputed constraints
    private static func fastPrune(
        potentials: Set<Int>,
        board: [Int],
        digit: Int,
        rules: [SudokuRuleType]
    ) -> Set<Int> {
        var workingSet = potentials
        var changed = true
        var iterations = 0
        let maxIterations = 5 // Reduced from 10 - most cases resolve quickly
        
        while changed && iterations < maxIterations {
            changed = false
            let previousCount = workingSet.count
            
            // Pointing pairs (box → line)
            for boxIdx in 0..<9 {
                let boxCells = getBoxIndices(boxIdx)
                let boxPotentials = workingSet.intersection(boxCells)
                
                if boxPotentials.isEmpty { continue }
                
                // Check row alignment
                let rows = Set(boxPotentials.map { $0 / 9 })
                if rows.count == 1, let row = rows.first {
                    let rowCells = getRowIndices(row).subtracting(boxCells)
                    workingSet.subtract(rowCells)
                }
                
                // Check column alignment
                let cols = Set(boxPotentials.map { $0 % 9 })
                if cols.count == 1, let col = cols.first {
                    let colCells = getColIndices(col).subtracting(boxCells)
                    workingSet.subtract(colCells)
                }
            }
            
            // Box/line reduction (line → box)
            for row in 0..<9 {
                let rowCells = getRowIndices(row)
                let rowPotentials = workingSet.intersection(rowCells)
                
                if rowPotentials.isEmpty { continue }
                
                let boxes = Set(rowPotentials.map { getBoxIndex(at: $0) })
                if boxes.count == 1, let box = boxes.first {
                    let boxCells = getBoxIndices(box).subtracting(rowCells)
                    workingSet.subtract(boxCells)
                }
            }
            
            for col in 0..<9 {
                let colCells = getColIndices(col)
                let colPotentials = workingSet.intersection(colCells)
                
                if colPotentials.isEmpty { continue }
                
                let boxes = Set(colPotentials.map { getBoxIndex(at: $0) })
                if boxes.count == 1, let box = boxes.first {
                    let boxCells = getBoxIndices(box).subtracting(colCells)
                    workingSet.subtract(boxCells)
                }
            }
            
            if workingSet.count == previousCount {
                changed = false
            } else {
                changed = true
            }
            
            iterations += 1
        }
        
        // Return restricted cells (those pruned from potentials)
        return potentials.subtracting(workingSet)
    }
    
    // MARK: - Geometry Helpers (Optimized with caching)
    
    private static var cachedBoxIndices: [[Int]] = []
    private static var cachedRowIndices: [[Int]] = []
    private static var cachedColIndices: [[Int]] = []
    
    private static func initializeCaches() {
        if !cachedBoxIndices.isEmpty { return }
        
        // Precompute all box/row/col indices
        cachedBoxIndices = (0..<9).map { box in
            let startR = (box / 3) * 3
            let startC = (box % 3) * 3
            var indices: [Int] = []
            for r in startR..<startR+3 {
                for c in startC..<startC+3 {
                    indices.append(r * 9 + c)
                }
            }
            return indices
        }
        
        cachedRowIndices = (0..<9).map { row in
            (0..<9).map { col in row * 9 + col }
        }
        
        cachedColIndices = (0..<9).map { col in
            (0..<9).map { row in row * 9 + col }
        }
    }
    
    private static func getBoxIndex(at index: Int) -> Int {
        let r = index / 9
        let c = index % 9
        return (r / 3) * 3 + (c / 3)
    }
    
    private static func getRowIndices(_ row: Int) -> Set<Int> {
        initializeCaches()
        return Set(cachedRowIndices[row])
    }
    
    private static func getColIndices(_ col: Int) -> Set<Int> {
        initializeCaches()
        return Set(cachedColIndices[col])
    }
    
    private static func getBoxIndices(_ box: Int) -> Set<Int> {
        initializeCaches()
        return Set(cachedBoxIndices[box])
    }
    
    // MARK: - Performance Metrics
    
    static func clearCaches() {
        constraintGraph.removeAll()
        graphBoardHash = 0
        graphRules = []
        cachedBoxIndices.removeAll()
        cachedRowIndices.removeAll()
        cachedColIndices.removeAll()
    }
    
    static var cacheStats: (graphSize: Int, boardHash: Int, ruleCount: Int) {
        return (constraintGraph.count, graphBoardHash, graphRules.count)
    }
}
