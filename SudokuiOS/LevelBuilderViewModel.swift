import SwiftUI
import SwiftData
import Combine

@MainActor
class LevelBuilderViewModel: ObservableObject {
    @Published var selectedTool: BuilderTool = .digit(1)
    
    enum BoardBaseType: String, CaseIterable {
        case classic = "Classic"
        case nonConsecutive = "Non-Consecutive"
        case king = "King Move"
        case knight = "Knight Move"
    }
    @Published var boardBaseType: BoardBaseType = .classic
    
    var cells: [SudokuCellModel] = []
    
    // Validation
    @Published var isValidating: Bool = false
    @Published var validationResult: String? = nil
    
    // Board Rules
    var arrows: [SudokuLevel.Arrow] = []
    var thermoPaths: [[[Int]]] = []
    var cages: [SudokuLevel.Cage] = []
    var whiteDots: [SudokuLevel.KropkiDot] = []
    var blackDots: [SudokuLevel.KropkiDot] = []
    
    // UI Drawing State
    @Published var isDrawing: Bool = false
    @Published var currentDrawingPath: [Int] = [] // Cell Indices
    
    enum BuilderTool: Equatable {
        case digit(Int)
        case erase
        case thermo
        case arrow
        case cage(Int) // Sum required
        case whiteDot
        case blackDot
        case oddEven(String) // "1" or "2"
    }
    
    init() {
        setupEmptyBoard()
    }
    
    private func setupEmptyBoard() {
        cells = (0..<81).map { i in
            let row = i / 9
            let col = i % 9
            return SudokuCellModel(id: i, row: row, col: col, value: 0, isClue: false)
        }
    }
    
    func handleCellTap(_ cellId: Int) {
        switch selectedTool {
        case .digit(let number):
            // Check max digits placed = 9
            let placedCount = cells.filter { $0.value == number && $0.isClue }.count
            if placedCount < 9 {
                cells[cellId].value = number
                cells[cellId].isClue = true
            }
        case .erase:
            cells[cellId].value = 0
            cells[cellId].isClue = false
            cells[cellId].parity = nil
            // In a fuller implementation, erasing a cell might also remove it from intersecting cages/thermos
        case .oddEven(let parity):
            cells[cellId].parity = parity
        default:
            break
        }
    }
    
    // Drag gestures for Thermo/Arrow/Cage
    func startDrawing(at cellId: Int) {
        guard isDrawingTool(selectedTool) else { return }
        isDrawing = true
        currentDrawingPath = [cellId]
    }
    
    func updateDrawing(to cellId: Int) {
        guard isDrawing, isDrawingTool(selectedTool) else { return }
        guard let last = currentDrawingPath.last, last != cellId else { return }
        
        // Constraint: Check Max Length
        if currentDrawingPath.count >= getMaxLength(for: selectedTool) {
            return
        }
        
        // Ensure adjacent
        let r1 = last / 9, c1 = last % 9
        let r2 = cellId / 9, c2 = cellId % 9
        let dR = abs(r1 - r2)
        let dC = abs(c1 - c2)
        
        let isAdjacent = (dR <= 1 && dC <= 1) && !(dR == 0 && dC == 0)
        
        if isAdjacent {
            if !currentDrawingPath.contains(cellId) {
                currentDrawingPath.append(cellId)
            }
        }
    }
    
    private func getMaxLength(for tool: BuilderTool) -> Int {
        switch tool {
        case .thermo:
            return boardBaseType == .nonConsecutive ? 5 : 9
        case .whiteDot, .blackDot:
            return 2
        default:
            return 81 // Cages and arrows can theoretically span broadly
        }
    }
    
    func endDrawing() {
        guard isDrawing else { return }
        isDrawing = false
        
        switch selectedTool {
        case .thermo:
            if currentDrawingPath.count > 1 {
                let pathCoords = currentDrawingPath.map { [$0 / 9, $0 % 9] }
                thermoPaths.append(pathCoords)
            }
        case .arrow:
            if currentDrawingPath.count > 1 {
                let bulb = [currentDrawingPath[0] / 9, currentDrawingPath[0] % 9]
                let lineCoords = currentDrawingPath.dropFirst().map { [$0 / 9, $0 % 9] }
                let arrow = SudokuLevel.Arrow(bulb: bulb, line: lineCoords)
                arrows.append(arrow)
            }
        case .cage(let sum):
            if currentDrawingPath.count > 0 {
                // Rule: Cages cannot overlap themselves
                let cellsCoords = currentDrawingPath.map { [$0 / 9, $0 % 9] }
                let uniqueCoords = Set(cellsCoords.map { "\($0[0]),\($0[1])" })
                if uniqueCoords.count != cellsCoords.count {
                    print("Error: Cage contains overlapping cells.")
                    currentDrawingPath.removeAll()
                    return
                }
                
                let cage = SudokuLevel.Cage(sum: sum, cells: cellsCoords)
                cages.append(cage)
            }
        case .whiteDot, .blackDot:
             if currentDrawingPath.count == 2 {
                 let r1 = currentDrawingPath[0] / 9
                 let c1 = currentDrawingPath[0] % 9
                 let r2 = currentDrawingPath[1] / 9
                 let c2 = currentDrawingPath[1] % 9
                 
                 let dot = SudokuLevel.KropkiDot(r1: r1, c1: c1, r2: r2, c2: c2)
                 if selectedTool == .whiteDot {
                     whiteDots.append(dot)
                 } else {
                     blackDots.append(dot)
                 }
             }
        default:
            break
        }
        
        currentDrawingPath.removeAll()
    }
    
    private func isDrawingTool(_ tool: BuilderTool) -> Bool {
        switch tool {
        case .thermo, .arrow, .cage, .whiteDot, .blackDot: return true
        default: return false
        }
    }
    
    var requiresDragToDraw: Bool {
        return isDrawingTool(selectedTool)
    }
    
    // MARK: - Saving & Validation
    
    private func buildCustomLevel() -> CustomSudokuLevel {
        let boardString = cells.map { "\($0.value)" }.joined()
        
        let rule: SudokuRuleType
        switch boardBaseType {
        case .classic: rule = .classic
        case .nonConsecutive: rule = .classic // Represented via isNonConsecutive below
        case .king: rule = .king
        case .knight: rule = .knight
        }
        
        return CustomSudokuLevel(
            board: boardString,
            difficulty: "Custom",
            ruleType: rule,
            isNonConsecutive: boardBaseType == .nonConsecutive,
            thermoPathsData: try? JSONEncoder().encode(thermoPaths),
            arrowsData: try? JSONEncoder().encode(arrows),
            cagesData: try? JSONEncoder().encode(cages),
            whiteDotsData: try? JSONEncoder().encode(whiteDots),
            blackDotsData: try? JSONEncoder().encode(blackDots)
        )
    }
    
    func saveLevel(context: ModelContext) {
        let customLevel = buildCustomLevel()
        context.insert(customLevel)
        do {
            try context.save()
            self.validationResult = "Saved successfully!"
        } catch {
            self.validationResult = "Failed to save: \(error.localizedDescription)"
        }
    }
    
    func checkValidation() {
        isValidating = true
        validationResult = nil
        
        let customLevel = buildCustomLevel()
        
        // Background logical solve on MainActor
        Task {
            let solver = HumanLogicSolver(level: customLevel)
            let (_, unsolvedCount, stalled) = solver.solve()
            
            self.isValidating = false
            
            if unsolvedCount == 0 && !stalled {
                self.validationResult = "Level has a unique Human-Solvable solution!"
            } else {
                self.validationResult = "Level is not cleanly Human-Solvable (Unsolved cells: \(unsolvedCount))"
            }
        }
    }
}
