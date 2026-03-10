import SwiftUI
import SwiftData
import Combine

@MainActor
class LevelBuilderViewModel: ObservableObject {
    @Published var selectedTool: BuilderTool = .digit(1) {
        didSet {
            // Commit any in-progress shape when switching tools
            if isShapeInProgress { finishCurrentShape() }
            // Clear Kropki selection when switching tools
            kropkiFirstCell = nil
        }
    }
    
    // MARK: - Multi-Select Global Rules (Req 2)
    @Published var isClassic: Bool = true
    @Published var isNonConsecutive: Bool = false
    @Published var isKing: Bool = false
    @Published var isKnight: Bool = false
    
    func toggleRule(_ rule: GlobalRule) {
        switch rule {
        case .classic:
            isClassic.toggle()
            if isClassic { isNonConsecutive = false }
        case .nonConsecutive:
            isNonConsecutive.toggle()
            if isNonConsecutive { isClassic = false }
        case .king:
            isKing.toggle()
        case .knight:
            isKnight.toggle()
        }
        // Ensure at least one base rule is active
        if !isClassic && !isNonConsecutive {
            isClassic = true
        }
    }
    
    enum GlobalRule: String, CaseIterable {
        case classic = "Classic"
        case nonConsecutive = "Non-Consec"
        case king = "King"
        case knight = "Knight"
    }
    
    func isRuleActive(_ rule: GlobalRule) -> Bool {
        switch rule {
        case .classic: return isClassic
        case .nonConsecutive: return isNonConsecutive
        case .king: return isKing
        case .knight: return isKnight
        }
    }
    
    // MARK: - Cells
    @Published var cells: [SudokuCellModel] = []
    
    // MARK: - Validation
    @Published var isValidating: Bool = false
    @Published var validationResult: String? = nil
    
    // MARK: - Board Rules Data (Published for UI reactivity)
    @Published var arrows: [SudokuLevel.Arrow] = []
    @Published var thermoPaths: [[[Int]]] = []
    @Published var cages: [SudokuLevel.Cage] = []
    @Published var whiteDots: [SudokuLevel.KropkiDot] = []
    @Published var blackDots: [SudokuLevel.KropkiDot] = []
    
    // MARK: - Sequential Tap Drawing State
    @Published var currentShapePath: [Int] = []
    var isShapeInProgress: Bool { !currentShapePath.isEmpty }
    @Published var showInvalidTapFeedback: Bool = false
    @Published var showCageSumPrompt: Bool = false
    @Published var pendingCageSum: String = ""
    var isPendingCageSumValid: Bool {
        guard let sum = Int(pendingCageSum) else { return false }
        return sum >= 1 && sum <= 45
    }
    
    // MARK: - Kropki Placement State (Req 4)
    @Published var kropkiFirstCell: Int? = nil
    
    // MARK: - Edit Mode
    var editingLevelID: UUID? = nil
    
    // MARK: - Save Name Prompt
    @Published var showSaveNamePrompt: Bool = false
    @Published var pendingLevelName: String = ""
    
    enum BuilderTool: Equatable {
        case digit(Int)
        case erase
        case thermo
        case arrow
        case cage
        case whiteDot
        case blackDot
        case oddEven(String)
    }
    
    // MARK: - Init
    
    init() {
        setupEmptyBoard()
    }
    
    init(existingLevel: CustomSudokuLevel) {
        setupEmptyBoard()
        hydrateFrom(existingLevel)
    }
    
    private func setupEmptyBoard() {
        cells = (0..<81).map { i in
            SudokuCellModel(id: i, row: i / 9, col: i % 9, value: 0, isClue: false)
        }
    }
    
    // MARK: - Edit Hydration
    
    private func hydrateFrom(_ level: CustomSudokuLevel) {
        editingLevelID = level.id
        
        // Board digits
        let boardChars = Array(level.board)
        for i in 0..<min(81, boardChars.count) {
            if let digit = Int(String(boardChars[i])), digit > 0 {
                cells[i].value = digit
                cells[i].isClue = true
            }
        }
        
        // Rule toggles
        isNonConsecutive = level.isNonConsecutive
        isClassic = !level.isNonConsecutive
        isKing = level.isKing
        isKnight = level.isKnight
        
        // Decode variant data
        if let data = level.thermoPathsData {
            thermoPaths = (try? JSONDecoder().decode([[[Int]]].self, from: data)) ?? []
        }
        if let data = level.arrowsData {
            arrows = (try? JSONDecoder().decode([SudokuLevel.Arrow].self, from: data)) ?? []
        }
        if let data = level.cagesData {
            cages = (try? JSONDecoder().decode([SudokuLevel.Cage].self, from: data)) ?? []
        }
        if let data = level.whiteDotsData {
            whiteDots = (try? JSONDecoder().decode([SudokuLevel.KropkiDot].self, from: data)) ?? []
        }
        if let data = level.blackDotsData {
            blackDots = (try? JSONDecoder().decode([SudokuLevel.KropkiDot].self, from: data)) ?? []
        }
    }
    
    // MARK: - Cell Tap Handling
    
    func handleCellTap(_ cellId: Int) {
        guard cellId >= 0, cellId < 81 else { return }
        
        switch selectedTool {
        case .digit(let number):
            let placedCount = cells.filter { $0.value == number && $0.isClue }.count
            if placedCount < 9 {
                cells[cellId].value = number
                cells[cellId].isClue = true
                objectWillChange.send()
            }
        case .erase:
            // 1. Clear Digit & Parity
            cells[cellId].value = 0
            cells[cellId].isClue = false
            cells[cellId].parity = nil
            
            // 2. Remove Whole Shapes (Thermos, Arrows, Cages)
            thermoPaths.removeAll { path in
                path.contains { coord in (coord[0] * 9 + coord[1]) == cellId }
            }
            
            arrows.removeAll { arrow in
                let headMatch = (arrow.bulb[0] * 9 + arrow.bulb[1]) == cellId
                let bodyMatch = arrow.line.contains { coord in (coord[0] * 9 + coord[1]) == cellId }
                return headMatch || bodyMatch
            }
            
            cages.removeAll { cage in
                cage.cells.contains { coord in (coord[0] * 9 + coord[1]) == cellId }
            }
            
            // 3. Remove Point Constraints (Kropki)
            whiteDots.removeAll { dot in
                (dot.r1 * 9 + dot.c1 == cellId) || (dot.r2 * 9 + dot.c2 == cellId)
            }
            blackDots.removeAll { dot in
                (dot.r1 * 9 + dot.c1 == cellId) || (dot.r2 * 9 + dot.c2 == cellId)
            }
            
            // 4. Clear Active Drawing States
            currentShapePath.removeAll()
            kropkiFirstCell = nil
            
            objectWillChange.send()
        case .oddEven(let parity):
            cells[cellId].parity = parity
            objectWillChange.send()
        case .thermo, .arrow, .cage:
            handleShapeTap(cellId)
        case .whiteDot, .blackDot:
            handleKropkiTap(cellId)
        }
    }
    
    // MARK: - Sequential Tap Drawing (Req 1)
    
    private func handleShapeTap(_ cellId: Int) {
        if currentShapePath.isEmpty {
            // Start new shape
            currentShapePath = [cellId]
            return
        }
        
        guard let lastCell = currentShapePath.last else { return }
        
        // Check already in path
        if currentShapePath.contains(cellId) {
            triggerInvalidFeedback()
            return
        }
        
        // Check adjacency
        guard isAdjacent(lastCell, cellId) else {
            triggerInvalidFeedback()
            return
        }
        
        // Check max length
        if currentShapePath.count >= getMaxLength(for: selectedTool) {
            triggerInvalidFeedback()
            return
        }
        
        currentShapePath.append(cellId)
    }
    
    func finishCurrentShape() {
        guard currentShapePath.count > 1 else {
            currentShapePath.removeAll()
            return
        }
        
        switch selectedTool {
        case .thermo:
            let pathCoords = currentShapePath.map { [$0 / 9, $0 % 9] }
            thermoPaths.append(pathCoords)
            currentShapePath.removeAll()
        case .arrow:
            let bulb = [currentShapePath[0] / 9, currentShapePath[0] % 9]
            let lineCoords = currentShapePath.dropFirst().map { [$0 / 9, $0 % 9] }
            let arrow = SudokuLevel.Arrow(bulb: bulb, line: lineCoords)
            arrows.append(arrow)
            currentShapePath.removeAll()
        case .cage:
            // Show sum prompt — don't clear path yet
            pendingCageSum = ""
            showCageSumPrompt = true
        default:
            currentShapePath.removeAll()
        }
    }
    
    /// Called after user enters cage sum in the alert
    func commitCageWithSum() {
        guard isPendingCageSumValid, currentShapePath.count > 1 else {
            currentShapePath.removeAll()
            return
        }
        let sum = Int(pendingCageSum)!
        let cellsCoords = currentShapePath.map { [$0 / 9, $0 % 9] }
        let cage = SudokuLevel.Cage(sum: sum, cells: cellsCoords)
        cages.append(cage)
        currentShapePath.removeAll()
    }
    
    func cancelCurrentShape() {
        currentShapePath.removeAll()
    }
    
    // MARK: - Kropki Dot Placement (Req 4)
    
    private func handleKropkiTap(_ cellId: Int) {
        guard selectedTool == .whiteDot || selectedTool == .blackDot else { return }
        
        if let firstCell = kropkiFirstCell {
            if isAdjacent(firstCell, cellId) {
                // Place dot between A and B
                let r1 = firstCell / 9, c1 = firstCell % 9
                let r2 = cellId / 9, c2 = cellId % 9
                let dot = SudokuLevel.KropkiDot(r1: r1, c1: c1, r2: r2, c2: c2)
                
                if selectedTool == .whiteDot {
                    whiteDots.append(dot)
                } else {
                    blackDots.append(dot)
                }
                kropkiFirstCell = nil
            } else {
                // Not adjacent — reassign
                kropkiFirstCell = cellId
            }
        } else {
            // First tap
            kropkiFirstCell = cellId
        }
    }
    
    // MARK: - Helpers
    
    private func isAdjacent(_ a: Int, _ b: Int) -> Bool {
        let r1 = a / 9, c1 = a % 9
        let r2 = b / 9, c2 = b % 9
        let dR = abs(r1 - r2)
        let dC = abs(c1 - c2)
        return (dR <= 1 && dC <= 1) && !(dR == 0 && dC == 0)
    }
    
    private func getMaxLength(for tool: BuilderTool) -> Int {
        switch tool {
        case .thermo:
            return isNonConsecutive ? 5 : 9
        case .arrow:
            return 10 // 1 head + max 9 body cells (sum ≤ 9)
        case .cage:
            return 9 // Mathematical rule: digits 1-9 cannot repeat, max 9 cells
        default:
            return 81
        }
    }
    
    private func triggerInvalidFeedback() {
        showInvalidTapFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.showInvalidTapFeedback = false
        }
    }
    
    func stepNumber(for cellId: Int) -> Int? {
        guard let idx = currentShapePath.firstIndex(of: cellId) else { return nil }
        return idx + 1
    }
    
    // MARK: - Saving & Validation
    
    private func buildCustomLevel(name: String = "Untitled") -> CustomSudokuLevel {
        let boardString = cells.map { "\($0.value)" }.joined()
        
        let rule: SudokuRuleType
        if isKing {
            rule = .king
        } else if isKnight {
            rule = .knight
        } else {
            rule = .classic
        }
        
        // Build parity string
        let parityString = cells.map { cell -> String in
            return cell.parity ?? "0"
        }.joined()
        let parityData = parityString.contains(where: { $0 != "0" }) ? parityString.data(using: .utf8) : nil
        
        let level = CustomSudokuLevel(
            id: editingLevelID ?? UUID(),
            levelName: name,
            board: boardString,
            difficulty: "Custom",
            ruleType: rule,
            isNonConsecutive: isNonConsecutive,
            isKing: isKing,
            isKnight: isKnight,
            thermoPathsData: try? JSONEncoder().encode(thermoPaths),
            arrowsData: try? JSONEncoder().encode(arrows),
            cagesData: try? JSONEncoder().encode(cages),
            whiteDotsData: try? JSONEncoder().encode(whiteDots),
            blackDotsData: try? JSONEncoder().encode(blackDots)
        )
        level.parityData = parityData
        return level
    }
    
    func saveLevel(context: ModelContext) {
        // Commit any in-progress shape before saving
        if isShapeInProgress { finishCurrentShape() }
        
        // Pre-fill default name if not already set (e.g. not editing or empty)
        if pendingLevelName.trimmingCharacters(in: .whitespaces).isEmpty {
            let descriptor = FetchDescriptor<CustomSudokuLevel>()
            let existingCount = (try? context.fetchCount(descriptor)) ?? 0
            pendingLevelName = "Level \(existingCount + 1)"
        }
        
        showSaveNamePrompt = true
        // Actual save happens in commitSave(context:)
    }
    
    func commitSave(context: ModelContext) {
        // Generate default name if blank
        var name = pendingLevelName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            let descriptor = FetchDescriptor<CustomSudokuLevel>()
            let existingCount = (try? context.fetchCount(descriptor)) ?? 0
            name = "Level \(existingCount + 1)"
        }
        
        let customLevel = buildCustomLevel(name: name)
        
        // If editing, delete old version first
        if let existingID = editingLevelID {
            let descriptor = FetchDescriptor<CustomSudokuLevel>(
                predicate: #Predicate { $0.id == existingID }
            )
            if let existing = try? context.fetch(descriptor).first {
                context.delete(existing)
            }
        }
        
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
