import Foundation

// MARK: - Human Logic Solver Engine
@MainActor
class HumanLogicSolver {
    var candidates: [[Set<Int>]]
    var rules: [SudokuRuleType]
    var cages: [SudokuLevel.Cage]
    var thermoPaths: [[[Int]]]
    var arrows: [SudokuLevel.Arrow]
    var whiteDots: [SudokuLevel.KropkiDot]
    var blackDots: [SudokuLevel.KropkiDot]
    var rowClues: [Int]
    var colClues: [Int]
    var parityOverlay: String?
    
    // Config
    var isNonConsecutive: Bool {
        return rules.contains(.nonConsecutive)
    }
    
    init(level: CustomSudokuLevel) {
        // Initialize 9x9 Candidates (1-9)
        self.candidates = Array(repeating: Array(repeating: Set(1...9), count: 9), count: 9)
        
        self.rules = [level.ruleType]
        if level.isNonConsecutive { self.rules.append(.nonConsecutive) }
        
        // Parse Placed Clues
        let boardArray = Array(level.board)
        for i in 0..<81 {
            if i < boardArray.count {
                if let val = boardArray[i].wholeNumberValue, val > 0 {
                    let r = i / 9
                    let c = i % 9
                    self.candidates[r][c] = [val]
                }
            }
        }
        
        // Parse Constraints
        self.thermoPaths = (try? JSONDecoder().decode([[[Int]]].self, from: level.thermoPathsData ?? Data())) ?? []
        self.arrows = (try? JSONDecoder().decode([SudokuLevel.Arrow].self, from: level.arrowsData ?? Data())) ?? []
        self.cages = (try? JSONDecoder().decode([SudokuLevel.Cage].self, from: level.cagesData ?? Data())) ?? []
        self.whiteDots = (try? JSONDecoder().decode([SudokuLevel.KropkiDot].self, from: level.whiteDotsData ?? Data())) ?? []
        self.blackDots = (try? JSONDecoder().decode([SudokuLevel.KropkiDot].self, from: level.blackDotsData ?? Data())) ?? []
        self.rowClues = (try? JSONDecoder().decode([Int].self, from: level.sandwichRowCluesData ?? Data())) ?? []
        self.colClues = (try? JSONDecoder().decode([Int].self, from: level.sandwichColCluesData ?? Data())) ?? []
        self.parityOverlay = nil // Omitted for brevity unless builder adds parity drawing
    }
    
    // MARK: - Core Execution
    
    // Solves returning: String mapping of board, Unsolved Cell Count, whether it changed
    func solve(maxIterations: Int = 100) -> (board: String, unsolvedCount: Int, didStall: Bool) {
        var didChange = true
        var loops = 0
        
        while didChange && loops < maxIterations {
            didChange = false
            loops += 1
            
            // Apply Rules Sequentially
            if applyClassicRules() { didChange = true; continue }
            if isNonConsecutive && applyNonConsecutiveImplications() { didChange = true; continue }
            if rules.contains(.knight) && applyKnightRules() { didChange = true; continue }
            if rules.contains(.king) && applyKingRules() { didChange = true; continue }
            if !thermoPaths.isEmpty && applyThermoRules() { didChange = true; continue }
            if !arrows.isEmpty && applyArrowRules() { didChange = true; continue }
            if !cages.isEmpty && applyKillerRules() { didChange = true; continue }
            if (!whiteDots.isEmpty || !blackDots.isEmpty) && applyKropkiRules() { didChange = true; continue }
            // Sandwich, OddEven...
        }
        
        let boardString = getBoardString()
        let unsolvedCount = candidates.flatMap { $0 }.filter { $0.count > 1 }.count
        let didStall = !didChange && unsolvedCount > 0
        
        return (boardString, unsolvedCount, didStall)
    }
    
    private func getBoardString() -> String {
        var result = ""
        for r in 0..<9 {
            for c in 0..<9 {
                if candidates[r][c].count == 1 {
                    result += "\(candidates[r][c].first!)"
                } else {
                    result += "0"
                }
            }
        }
        return result
    }
    
    // MARK: - Validation API
    
    static func isHumanSolvable(level: CustomSudokuLevel) -> Bool {
        let solver = HumanLogicSolver(level: level)
        let (_, unsolved, stalled) = solver.solve()
        return unsolved == 0 && !stalled
    }
    
    // MARK: - Utilities
    
    private func removeCandidate(r: Int, c: Int, val: Int) -> Bool {
        if candidates[r][c].contains(val) {
            candidates[r][c].remove(val)
            return true
        }
        return false
    }
    
    private func getHouses(r: Int, c: Int) -> [[(Int, Int)]] {
        var houses: [[(Int, Int)]] = []
        houses.append((0..<9).map { (r, $0) }) // Row
        houses.append((0..<9).map { ($0, c) }) // Col
        
        let br = (r / 3) * 3
        let bc = (c / 3) * 3
        var box: [(Int, Int)] = []
        for i in 0..<9 { box.append((br + (i/3), bc + (i%3))) } // Box
        houses.append(box)
        
        return houses
    }
    
    private func getNeighbors(r: Int, c: Int) -> [(Int, Int)] {
        let dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        var neighbors: [(Int, Int)] = []
        for d in dirs {
            let nr = r + d.0
            let nc = c + d.1
            if nr >= 0, nr < 9, nc >= 0, nc < 9 {
                neighbors.append((nr, nc))
            }
        }
        return neighbors
    }
    
    // MARK: - Handlers
    
    private func applyClassicRules() -> Bool {
        var changed = false
        
        // 1. Naked Singles
        for r in 0..<9 {
            for c in 0..<9 {
                if candidates[r][c].count == 1 {
                    let val = candidates[r][c].first!
                    for house in getHouses(r: r, c: c) {
                        for (hr, hc) in house {
                            if (hr, hc) != (r, c) {
                                if removeCandidate(r: hr, c: hc, val: val) { changed = true }
                            }
                        }
                    }
                }
            }
        }
        
        // 2. Hidden Singles
        for r in 0..<9 {
            for c in 0..<9 {
                if candidates[r][c].count > 1 {
                    var foundHidden = false
                    for val in Array(candidates[r][c]) {
                        if !candidates[r][c].contains(val) { continue }
                        
                        for house in getHouses(r: r, c: c) {
                            var count = 0
                            for (hr, hc) in house {
                                if candidates[hr][hc].contains(val) { count += 1 }
                            }
                            if count == 1 {
                                // Eliminate others
                                let toRemove = candidates[r][c].filter { $0 != val }
                                for v in toRemove {
                                    if removeCandidate(r: r, c: c, val: v) { changed = true }
                                }
                                foundHidden = true
                                break
                            }
                        }
                        if foundHidden { break }
                    }
                }
            }
        }
        
        return changed
    }
    
    // Abstracting out others for brevity of plan - we will implement exact equivalents as required.
    private func applyNonConsecutiveImplications() -> Bool {
        var changed = false
        for r in 0..<9 {
            for c in 0..<9 {
                if candidates[r][c].count == 1 {
                    let val = candidates[r][c].first!
                    for (nr, nc) in getNeighbors(r: r, c: c) {
                        if removeCandidate(r: nr, c: nc, val: val - 1) { changed = true }
                        if removeCandidate(r: nr, c: nc, val: val + 1) { changed = true }
                    }
                }
            }
        }
        return changed
    }
    
    private func applyKnightRules() -> Bool { return false }
    private func applyKingRules() -> Bool { return false }
    private func applyThermoRules() -> Bool { return false }
    private func applyArrowRules() -> Bool { return false }
    private func applyKillerRules() -> Bool { return false }
    private func applyKropkiRules() -> Bool { return false }
}
