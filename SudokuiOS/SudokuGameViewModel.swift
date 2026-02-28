import Foundation
import Combine
import SwiftUI
import SwiftData
import Observation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
class SudokuCellModel: Identifiable {
    let id: Int
    var value: Int
    var notes: Set<Int>
    var color: Int?
    var hasCross: Bool
    let isClue: Bool
    
    init(id: Int, value: Int, notes: Set<Int> = [], color: Int? = nil, hasCross: Bool = false, isClue: Bool) {
        self.id = id
        self.value = value
        self.notes = notes
        self.color = color
        self.hasCross = hasCross
        self.isClue = isClue
    }
}

@MainActor
class SudokuGameViewModel: ObservableObject {
    let levelID: Int
    private var parentViewModel: LevelViewModel
    var levelViewModel: LevelViewModel { parentViewModel } // Expose for View access
    
    // Game State
    @Published var currentBoard: String = ""
    private(set) var currentBoardArray: [Int] = Array(repeating: 0, count: 81)
    @Published var selectedCellIndex: Int?
    @Published var isSolved: Bool = false
    @Published var isGameComplete: Bool = false 
    
    // Multi-Select
    @Published var isMultiSelectMode: Bool = false
    @Published var selectedIndices: Set<Int> = []
    
    // Wave Effect State
    @Published var isWaveActive: Bool = false
    @Published var waveOrigin: Int? = nil
    @Published var waveRadius: CGFloat = 0.0
    @Published var revealedMistakeIndices: Set<Int> = []
    private var waveTimer: Timer?
    
    // Sandwich Helper State
    struct SelectedClueInfo {
        let id: String // e.g., "Row-2", "Col-5"
        let sum: Int
    }
    
    @Published var selectedClue: SelectedClueInfo?
    @Published var markedCombinations: [String: Set<[Int]>] = [:] // Key: ClueID
    
    // Explicit Highlight (Number Pad Toggle)
    @Published var explicitHighlightedDigit: Int? = nil
    
    func selectClue(index: Int, isRow: Bool, sum: Int) {
        let id = isRow ? "Row-\(index)" : "Col-\(index)"
        
        // Auto-Selection Logic: If no state exists for this clue, select ALL valid combinations by default.
        if markedCombinations[id] == nil {
             let allCombos = SandwichMath.getSandwichCombinations(for: sum)
             markedCombinations[id] = Set(allCombos)
             saveState() // Instant persistence for defaults
        }
        
        selectedClue = SelectedClueInfo(id: id, sum: sum)
    }
    
    // Pointing Pairs / Line-Box Reduction Cache
    @Published var pointPairRestrictions: Set<Int> = []
    
    func updatePointPairRestrictions() {
        guard let digit = selectedDigit, digit > 0 else {
            pointPairRestrictions = []
            return
        }
        
        // Only valid for Potential Mode
        if settings?.highlightMode == .potential {
             // Pass parity string if rule is OddEven
             let parity = (ruleType == .oddEven) ? parityOverlay : nil
             
             pointPairRestrictions = PointingPairsSolver.getPointedRestrictions(
                board: currentBoard,
                digit: digit,
                parityString: parity,
                ruleType: ruleType ?? .classic,
                whiteDots: whiteDots,
                blackDots: blackDots,
                negativeConstraint: negativeConstraint
             )
        } else {
            pointPairRestrictions = []
        }
    }
    
    func dismissSandwichHelper() {
        selectedClue = nil
    }
    
    func toggleCombination(_ combination: [Int]) {
        guard let clueID = selectedClue?.id else { return }
        
        var currentSet = markedCombinations[clueID] ?? []
        if currentSet.contains(combination) {
            currentSet.remove(combination)
        } else {
            currentSet.insert(combination)
        }
        markedCombinations[clueID] = currentSet
        
        // Save immediately
        saveState()
    }
    
    // Highlight Settings
    // Uses settings reference
    
    // History
    var historyIndex: Int = -1 
    
    var levelProgress: UserLevelProgress? 
    
    var settings: AppSettings?
    
    func setSettings(_ settings: AppSettings) {
        // Only update if changed to avoid redundant View updates
        if self.settings !== settings {
            self.settings = settings
        }
    }
    
    // Static Data
    var initialBoard: String = "" // Clues
    private var solution: String = ""
    private(set) var initialBoardArray: [Int] = Array(repeating: 0, count: 81)
    private var solutionArray: [Int] = Array(repeating: 0, count: 81)
    
    // Helper: parse board string → [Int]
    private static func parseBoardString(_ s: String) -> [Int] {
        var result = [Int](repeating: 0, count: 81)
        var i = 0
        for ch in s {
            guard i < 81 else { break }
            result[i] = ch.wholeNumberValue ?? 0
            i += 1
        }
        return result
    }
    @Published var rules: [SudokuRuleType] = [] // Active Rules (Hybrid)
    @Published var ruleType: SudokuRuleType? // Primary/Display Rule (Legacy)
    @Published var rowClues: [Int]?
    @Published var colClues: [Int]?
    @Published var thermoPaths: [[[Int]]]?
    @Published var cages: [SudokuLevel.Cage]?
    @Published var arrows: [SudokuLevel.Arrow]?
    @Published var whiteDots: [SudokuLevel.KropkiDot]?
    @Published var blackDots: [SudokuLevel.KropkiDot]?
    @Published var negativeConstraint: Bool = false
    @Published var parityOverlay: String? // For Odd-Even Sudoku

    

    
    @Published var kropkiErrors: Set<KropkiBorder> = []
    
    // Palette
    static let palette: [Color] = [
        Color.red.opacity(0.3), Color.orange.opacity(0.3), Color.yellow.opacity(0.3),
        Color.green.opacity(0.3), Color.mint.opacity(0.3), Color.teal.opacity(0.3),
        Color.cyan.opacity(0.3), Color.blue.opacity(0.3), Color.indigo.opacity(0.3),
        Color.purple.opacity(0.3), Color.pink.opacity(0.3), Color.brown.opacity(0.3)
    ]
    
    var cellCrosses: [Int: Bool] = [:] // Temporary storage during init
    
    init(levelID: Int, levelViewModel: LevelViewModel) {
        self.levelID = levelID
        self.parentViewModel = levelViewModel

        loadLevelData()
        
        // Track Last Unfinished Level
        UserDefaults.standard.set(levelID, forKey: "lastUnfinishedLevelID")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastPlayedTimestamp")
    }
    
    private func loadLevelData() {
        // Ensure data is loaded in parent
        if parentViewModel.levels.isEmpty {
            parentViewModel.loadLevelsFromJSON()
        }
        
        guard let level = parentViewModel.levels.first(where: { $0.id == levelID }) else {
            let emptyBoard = String(repeating: "0", count: 81)
            currentBoard = emptyBoard
            initialBoard = emptyBoard
            currentBoardArray = Array(repeating: 0, count: 81)
            initialBoardArray = Array(repeating: 0, count: 81)
            return
        }
        
        // 1. Set Static Data (Clues & Solution)
        self.initialBoard = level.board ?? String(repeating: "0", count: 81)
        self.solution = level.solution ?? ""
        self.initialBoardArray = Self.parseBoardString(self.initialBoard)
        self.solutionArray = Self.parseBoardString(self.solution)
        self.rowClues = level.rowClues
        self.colClues = level.colClues
        self.thermoPaths = level.thermoPaths
        self.cages = level.cages
        self.arrows = level.arrows
        self.whiteDots = level.white_dots
        self.blackDots = level.black_dots
        self.negativeConstraint = level.negative_constraint ?? false
        self.parityOverlay = level.parity
        self.isSolved = level.isSolved
        
        self.ruleType = level.ruleType
        // Hybrid Support: Use 'types' if available, otherwise fallback to single 'ruleType'
        if !level.types.isEmpty {
            self.rules = level.types
        } else {
            self.rules = [level.ruleType]
        }
        
        // 2. Set Current State (User Progress > Static Board)
        if let progress = level.userProgress {
            self.currentBoard = progress
            self.timeElapsed = level.timeElapsed
        } else {
            self.currentBoard = self.initialBoard
            self.timeElapsed = 0
        }
        
        // 3. Load Notes
        if let notesData = level.notesData {
            if let decodedStringNotes = try? JSONDecoder().decode([String: Set<Int>].self, from: notesData) {
                self.notes = Dictionary(uniqueKeysWithValues: decodedStringNotes.compactMap { (key, val) in
                    guard let intKey = Int(key) else { return nil }
                    return (intKey, val)
                })
            } else if let decodedNotes = try? JSONDecoder().decode([Int: Set<Int>].self, from: notesData) {
                self.notes = decodedNotes
            }
        }
        
        // 5. Load Colors
        if let colorData = level.colorData {
             if let decodedStringColors = try? JSONDecoder().decode([String: Int].self, from: colorData) {
                 self.cellColors = Dictionary(uniqueKeysWithValues: decodedStringColors.compactMap { (key, val) in
                     guard let intKey = Int(key) else { return nil }
                     return (intKey, val)
                 })
             } else if let decodedColors = try? JSONDecoder().decode([Int: Int].self, from: colorData) {
                 self.cellColors = decodedColors
             }
        }
        
        // 6. Load Marked Combinations (Sandwich)
        if let comboData = level.markedCombinationsData {
            if let decodedCombos = try? JSONDecoder().decode([String: Set<[Int]>].self, from: comboData) {
                self.markedCombinations = decodedCombos
            }
        }
        
        // 7. Load Cross Data (Sandwich)
        if let crossData = level.crossData {
             if let decodedCrosses = try? JSONDecoder().decode([Int: Bool].self, from: crossData) {
                 self.cellCrosses = decodedCrosses
             }
        }
        
        // 5. Load Persistent Object for History
        if let progress = parentViewModel.getProgress(for: levelID) {
            self.levelProgress = progress
            if let moves = progress.moves, !moves.isEmpty {
                self.historyIndex = moves.count - 1
            }
        } else {
            if let context = parentViewModel.modelContext {
                let newProgress = UserLevelProgress(levelID: levelID, isSolved: level.isSolved)
                newProgress.currentUserBoard = self.currentBoard
                context.insert(newProgress)
                self.levelProgress = newProgress
                self.historyIndex = -1
                try? context.save()
            }
        }
        
        // 6. Initialize Observable Cells
        initializeCells()
    }
    
    @Published var cells: [SudokuCellModel] = []
    
    private func initializeCells() {
        var newCells: [SudokuCellModel] = []
        var boardChars = Array(currentBoard)
        let initialChars = Array(initialBoard) // For validation
        
        if boardChars.count < 81 {
            boardChars = Array(String(repeating: "0", count: 81))
        }
        
        for i in 0..<81 {
            var val = Int(String(boardChars[i])) ?? 0
            
            // Self-Healing: If it's a clue (in initialBoard), it MUST have the value
            let clue = isClue(at: i)
            if clue {
                let initialVal = Int(String(initialChars[i])) ?? 0
                if val != initialVal {
                     // Corrupted state or stale progress -> Fix it
                     val = initialVal
                }
            }
            
            let n = notes[i] ?? []
            let c = cellColors[i]
            let cross = cellCrosses[i] ?? false
            newCells.append(SudokuCellModel(id: i, value: val, notes: n, color: c, hasCross: cross, isClue: clue))
        }
        self.cells = newCells
        
        // Sync back fixed board to currentBoard string immediately to fix save state
        var boardArr = [Int](repeating: 0, count: 81)
        var chars = [Character]()
        chars.reserveCapacity(81)
        for cell in newCells {
            boardArr[cell.id] = cell.value
            chars.append(Character(String(cell.value)))
        }
        let fixedBoardString = String(chars)
        self.currentBoardArray = boardArr
        if fixedBoardString != currentBoard {
            self.currentBoard = fixedBoardString
            
            // Defer saving to avoid "Publishing changes from within view updates" warning
            // since this might happen during init/view construction.
            Task { @MainActor in
                self.saveState()
            }
        }
    }
    
    func saveState() {
        var boardArr = [Int](repeating: 0, count: 81)
        var chars = [Character]()
        chars.reserveCapacity(81)
        for cell in cells {
            let idx = cell.id
            boardArr[idx] = cell.value
            chars.append(Character(String(cell.value)))
        }
        let currentBoardString = String(chars)
        self.currentBoard = currentBoardString
        self.currentBoardArray = boardArr
        
        var notesDict: [String: Set<Int>] = [:]
        var colorsDict: [String: Int] = [:]
        var crossesDict: [Int: Bool] = [:]
        
        for cell in cells {
            if !cell.notes.isEmpty {
                notesDict[String(cell.id)] = cell.notes
            }
            if let color = cell.color {
                colorsDict[String(cell.id)] = color
            }
            if cell.hasCross {
                crossesDict[cell.id] = true
            }
        }
        
        let notesData = try? JSONEncoder().encode(notesDict)
        let colorData = try? JSONEncoder().encode(colorsDict)
        let markedCombinationsData = try? JSONEncoder().encode(markedCombinations)
        let crossData = try? JSONEncoder().encode(crossesDict)
        
        parentViewModel.saveLevelProgress(levelId: levelID, currentBoard: currentBoardString, notesData: notesData, colorData: colorData, markedCombinationsData: markedCombinationsData, crossData: crossData, timeElapsed: timeElapsed)
    }
    
    // MARK: - Input Logic
    
    @Published var isNoteMode: Bool = false
    @Published var notes: [Int: Set<Int>] = [:] 
    @Published var cellColors: [Int: Int] = [:]
    // ruleType moved to top
    
    // Timer
    @Published var timeElapsed: Int = 0
    
    private var timer: Timer?
    @Published var isTimerRunning: Bool = false
    
    func toggleNoteMode() {
        isNoteMode.toggle()
    }
    
    @Published var boardID = UUID()
    
    func selectCell(_ index: Int) {
        // Reset Explicit Highlight immediately (State Priority)
        explicitHighlightedDigit = nil
        
        let isAlreadySelected = selectedIndices.contains(index)
        
        if isAlreadySelected {
            // Toggle OFF behavior (Requested)
            selectedIndices.remove(index)
            triggerHaptic()
            
            // Cleanup Anchor if needed
            if selectedCellIndex == index {
                selectedCellIndex = nil
            }
        } else {
            // Toggle ON behavior
            if isMultiSelectMode {
                // Multi-Mode: Additive
                selectedIndices.insert(index)
            } else {
                // Single-Mode: Exclusive (Clear others)
                selectedIndices = [index]
            }
            selectedCellIndex = index
        }
        
        updateRestrictions()
    }
    
    private func triggerHaptic() {
        #if os(iOS)
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
        #endif
    }
    
    // Gesture Start Logic: Handles Mode-Specific Reset
    func gestureStart(at index: Int) {
        if !isMultiSelectMode {
            // Single Mode
            // RESET IF:
            // 1. Touching outside (indices doesn't contain index)
            // 2. OR Touching inside BUT we have multiple selected (User wants to isolate this one)
            if !selectedIndices.contains(index) || selectedIndices.count > 1 {
                selectedIndices.removeAll()
                selectedCellIndex = nil
            }
        }
        // Multi Mode: Do nothing (Additive by default)
    }

    // Drag Toggle Logic (Distinct from Tap Selection)
    // Always treats interaction as "Multi-Select" equivalent (additive/toggle), never clears others.
    func dragToggle(_ index: Int) {
        // Reset Explicit Highlight (State Priority)
        explicitHighlightedDigit = nil
        
        if selectedIndices.contains(index) {
             selectedIndices.remove(index)
             triggerHaptic()
             if selectedCellIndex == index {
                 selectedCellIndex = nil
             }
        } else {
             selectedIndices.insert(index)
             selectedCellIndex = index // Update anchor to latest touched
        }
        
        updateRestrictions()
        updatePointPairRestrictions()
    }
    
    // Derived property for Note Highlighting
    var selectedDigit: Int? {
        // Priority: Explicit Global Highlight -> Selected Cell's Value
        if let explicit = explicitHighlightedDigit {
            return explicit
        }
        guard let index = selectedCellIndex, index < cells.count else { return nil }
        let val = cells[index].value
        return val != 0 ? val : nil
    }
    
    // Drag Selection Logic (Reduces redundant updates)
    func dragSelect(_ index: Int, isStart: Bool = false) {
        guard index >= 0 && index < 81 else { return }
        
        // Reset Explicit Highlight immediately (State Priority)
        if explicitHighlightedDigit != nil {
            explicitHighlightedDigit = nil
        }
        
        if isMultiSelectMode {
            // Multi Mode: Additive "Paint" Selection (Do not toggle off)
            if !selectedIndices.contains(index) {
                selectedIndices.insert(index)
                selectedCellIndex = index
            }
        } else {
            // Standard Drag-to-Select (Pseudo-Multi)
            if isStart {
                // New Gesture: Start fresh
                selectedIndices = [index]
                selectedCellIndex = index
            } else {
                // Continuing Gesture: Additive
                if !selectedIndices.contains(index) {
                    selectedIndices.insert(index)
                    selectedCellIndex = index
                } else if selectedCellIndex != index {
                     // Even if already selected, update anchor for visual feedback/restrictions
                     selectedCellIndex = index
                }
            }
        }
        updateRestrictions()
        updatePointPairRestrictions()
    }
    
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
    }
    
    func setCellColor(_ paletteIndex: Int) {
        let batchID = selectedIndices.count > 1 ? UUID() : nil
        
        for index in selectedIndices {
            let cell = cells[index]
            let oldColor = cell.color
            
            // Toggle Logic: If setting same color, clear it (nil). Otherwise set new color.
            let newColor: Int? = (oldColor == paletteIndex) ? nil : paletteIndex
            
            // If no change (e.g. was nil, setting nil?? won't happen here but good check), skip
            if oldColor == newColor { continue }
            
            // Prepare string for History
            let newValueString = newColor.map(String.init) ?? "clear"
            
            addMove(cellIndex: index, moveType: "Color", oldValue: oldColor.map(String.init), newValue: newValueString, batchID: batchID, performSave: false)
            cell.color = newColor
        }
        
        finishBatchUpdate()
    }
    
    func clearCellColor() {
        let batchID = selectedIndices.count > 1 ? UUID() : nil
        
        for index in selectedIndices {
            let cell = cells[index]
            let oldColor = cell.color
            
            if oldColor == nil { continue }
            
            addMove(cellIndex: index, moveType: "Color", oldValue: oldColor.map(String.init), newValue: "clear", batchID: batchID, performSave: false)
            cell.color = nil
        }
        finishBatchUpdate()
    }
    
    func toggleCross() {
        let batchID = selectedIndices.count > 1 ? UUID() : nil
        
        // 1. Filter valid cells (cannot cross meaningful numbers)
        let validIndices = selectedIndices.filter { cells[$0].value == 0 }
        
        guard !validIndices.isEmpty else { return }
        
        // Logic: If ANY valid cell is missing the cross, we ADD it to all.
        //        Only if ALL valid cells have the cross do we REMOVE it from all.
        let shouldAdd = validIndices.contains { !cells[$0].hasCross }
        
        for index in validIndices {
            let cell = cells[index]
            
            if cell.hasCross != shouldAdd {
                let oldValue = cell.hasCross ? "true" : "false"
                let newValue = shouldAdd ? "true" : "false"
                
                addMove(cellIndex: index, moveType: "Cross", oldValue: oldValue, newValue: newValue, batchID: batchID, performSave: false)
                
                cell.hasCross = shouldAdd
            }
        }
        finishBatchUpdate()
    }
    
    func erase() {
        let batchID = selectedIndices.count > 1 ? UUID() : nil
        
        let wasFullStart = isBoardFull
        
        for index in selectedIndices {
            let cell = cells[index]
            // Allow erasing color from Clues, so we don't skip them entirely.
            
            let oldColor = cell.color
            
            // 1. Color (Applies to ALL cells, including clues)
            if cell.color != nil {
                cell.color = nil
                addMove(cellIndex: index, moveType: "Color", oldValue: oldColor.map(String.init), newValue: "clear", batchID: batchID, performSave: false)
            }
            
            // 2. Content (Editable cells only)
            if !cell.isClue {
                let oldBoardValue = String(cell.value)
                let oldNotesString = cell.notes.sorted().map{String($0)}.joined(separator: ",")
                
                if cell.value != 0 {
                    cell.value = 0
                    
                    // Clear revealed state
                    revealedMistakeIndices.remove(index)
                    
                    addMove(cellIndex: index, moveType: "Value", oldValue: oldBoardValue, newValue: "0", batchID: batchID, performSave: false)
                }
                
                if !cell.notes.isEmpty {
                    cell.notes = []
                    addMove(cellIndex: index, moveType: "Note", oldValue: oldNotesString, newValue: "", batchID: batchID, performSave: false)
                }
                
                if cell.hasCross {
                    cell.hasCross = false
                    let oldCrossValue = "true"
                    addMove(cellIndex: index, moveType: "Cross", oldValue: oldCrossValue, newValue: "false", batchID: batchID, performSave: false)
                }
            }
        }
        
        finishBatchUpdate(checkWin: true, wasBoardFull: wasFullStart)
        updatePointPairRestrictions()
    }

    @MainActor
    func enterNumber(_ number: Int) {
        // Enforce Note Mode if explicit Note Mode is on OR multiple cells are selected
        if isNoteMode || selectedIndices.count > 1 {
            toggleNote(number)
        } else {
            applyNumberBatch(number)
            updatePointPairRestrictions()
        }
    }
    
    @MainActor
    func applyNumberBatch(_ number: Int) {
        // ALWAYS use a batchID to ensure atomicity of (Clear Notes + Set Value) even for single cells
        let batchID = UUID()
        
        // Capture State BEFORE Changes
        let wasFullStart = isBoardFull
        
        // 1. Perform all data changes in one loop
        for index in selectedIndices {
            guard !isClue(at: index) else { continue }
            
            let cell = cells[index]
            let oldValue = String(cell.value)
            
            // Toggle Logic: If cell value matches pressed number, clear it. Otherwise set it.
            let targetValue = (cell.value == number) ? 0 : number
            let newValue = String(targetValue)
            
            // Optimization: If value is same and notes are empty, skip
            if oldValue == newValue && cell.notes.isEmpty { continue }
            
            // Clear notes if present (Atomic Part 1)
            // We clear notes if we are setting a value, OR if we are just clearing 
            // (though usually notes are empty if value is present, but good for safety)
            let oldNotesString = cell.notes.sorted().map{String($0)}.joined(separator: ",")
            if !cell.notes.isEmpty {
                cell.notes = []
                addMove(cellIndex: index, moveType: "Note", oldValue: oldNotesString, newValue: "", batchID: batchID, performSave: false)
            }
            
            // Clear Cross if present (Atomic Part 1.5)
            if cell.hasCross {
                cell.hasCross = false
                // Note: Not tracking cross in history yet, just executing the logic
            }
            
            // Update Value (Atomic Part 2)
            if oldValue != newValue {
                cell.value = targetValue
                
                // Clear revealed state for this cell when edited
                revealedMistakeIndices.remove(index)
                
                addMove(cellIndex: index, moveType: "Value", oldValue: oldValue, newValue: newValue, batchID: batchID, performSave: false)
                
                // 3. Auto-Pruning Hook (If setting a value)
                if targetValue != 0 {
                    autoPruneNotes(for: index, value: targetValue, batchID: batchID)
                }
            }
        }
        
        // 2. Force SwiftData to save and notify observers immediately
        // 2. Force SwiftData to save and notify observers immediately
        finishBatchUpdate(checkWin: true, wasBoardFull: wasFullStart)
        
        // 3. Trigger a manual UI 'Pulse'
        self.objectWillChange.send()
    }
    
    @MainActor
    func toggleNote(_ number: Int) {
        // ALWAYS use a batchID for atomicity
        let batchID = UUID()
        
        // 1. Identify valid cells (Skip cells that already have a value)
        let validIndices = selectedIndices.filter { cells[$0].value == 0 }
        
        // 2. Determine Action: Add or Remove?
        // Logic: If ANY valid cell is missing the note, we ADD it to all.
        //        Only if ALL valid cells have the note do we REMOVE it from all.
        let shouldAdd = validIndices.contains { !cells[$0].notes.contains(number) }
        
        for index in validIndices {
            let cell = cells[index]
            
            var currentNotes = cell.notes
            let oldNotesString = currentNotes.sorted().map{String($0)}.joined(separator: ",")
            
            if shouldAdd {
                currentNotes.insert(number)
            } else {
                currentNotes.remove(number)
            }
            
            let newNotesString = currentNotes.sorted().map{String($0)}.joined(separator: ",")
            
            if oldNotesString != newNotesString {
                cell.notes = currentNotes
                addMove(cellIndex: index, moveType: "Note", oldValue: oldNotesString, newValue: newNotesString, batchID: batchID, performSave: false)
            }
        }
        
        finishBatchUpdate()
        
        // Trigger UI Pulse to ensure views switch from Value to Note mode instantly
        self.objectWillChange.send()
    }
    
    
    private func finishBatchUpdate(checkWin: Bool = false, wasBoardFull: Bool = false) {
        saveState()
        parentViewModel.modelContext?.processPendingChanges()
        // boardID = UUID() // REMOVED: Do not force full grid redraw. @Observable cells handle updates.
        updateRestrictions()
        checkKropkiErrors()
        
        if checkWin {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                checkForWin(wasBoardFull: wasBoardFull)
            }
        }
    }

    private func autoPruneNotes(for index: Int, value: Int, batchID: UUID) {
        // Standard Sudoku Pruning (Row, Col, Box)
        // Gather all indices in same neighborhood
        var indicesToPrune = Set<Int>()
        
        let row = index / 9
        let col = index % 9
        let boxRow = row / 3
        let boxCol = col / 3
        
        // Row & Col
        for k in 0..<9 {
            indicesToPrune.insert(row * 9 + k) // Row
            indicesToPrune.insert(k * 9 + col) // Col
        }
        
        // Box
        for r in (boxRow * 3)..<(boxRow * 3 + 3) {
            for c in (boxCol * 3)..<(boxCol * 3 + 3) {
                indicesToPrune.insert(r * 9 + c)
            }
        }

        // Remove self from pruning list (though logic handles it by checking 'value == 0')
        indicesToPrune.remove(index)
        
        // Apply Pruning
        for pruneIndex in indicesToPrune {
            let cell = cells[pruneIndex]
            guard cell.value == 0 else { continue } // Only prune notes from empty cells
            
            var currentNotes = cell.notes
            if currentNotes.contains(value) {
                let oldNotesString = currentNotes.sorted().map{String($0)}.joined(separator: ",")
                currentNotes.remove(value)
                let newNotesString = currentNotes.sorted().map{String($0)}.joined(separator: ",")
                
                cell.notes = currentNotes
                addMove(cellIndex: pruneIndex, moveType: "Note", oldValue: oldNotesString, newValue: newNotesString, batchID: batchID, performSave: false)
            }
        }
        
        // Non-Consecutive Variant Pruning
        if isNonConsecutive {
            let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)] // Up, Down, Left, Right
            let valuesToRemove = [value - 1, value + 1]
            
            for (dr, dc) in directions {
                let r = row + dr
                let c = col + dc
                
                if r >= 0 && r < 9 && c >= 0 && c < 9 {
                    let neighborIndex = r * 9 + c
                    // Only prune if we haven't already processed it (though Standard covered row/col neighbors, 
                    // it didn't cover N-1/N+1 removal. So we must process even if 'indicesToPrune' contained it, 
                    // or simply run this independently.)
                    
                    let cell = cells[neighborIndex]
                    guard cell.value == 0 else { continue }
                    
                    var currentNotes = cell.notes
                    var changed = false
                    
                    for v in valuesToRemove {
                        if currentNotes.contains(v) {
                            currentNotes.remove(v)
                            changed = true
                        }
                    }
                    
                    if changed {
                        let oldNotesString = cell.notes.sorted().map{String($0)}.joined(separator: ",")
                        let newNotesString = currentNotes.sorted().map{String($0)}.joined(separator: ",")
                        
                        cell.notes = currentNotes
                        addMove(cellIndex: neighborIndex, moveType: "Note", oldValue: oldNotesString, newValue: newNotesString, batchID: batchID, performSave: false)
                    }
                }
            }
        }
    }
    
    @MainActor
    func didTapNumber(_ number: Int) {
        if selectedCellIndex == nil && selectedIndices.isEmpty {
            // No cell selected -> Toggle Number Pad Highlight
            if explicitHighlightedDigit == number {
                explicitHighlightedDigit = nil
            } else {
                explicitHighlightedDigit = number
            }
        } else {
            if isNoteMode {
                toggleNote(number)
            } else {
                enterNumber(number)
            }
        }
    }

    func isClue(at index: Int) -> Bool {
        guard index < initialBoardArray.count else { return false }
        return initialBoardArray[index] != 0
    }
    
    // MARK: - Victory Wave Logic
    
    func triggerVictoryWave(from index: Int) {
        guard !isWaveActive else { return }
        
        isWaveActive = true
        waveOrigin = index
        waveRadius = 0.0
        revealedMistakeIndices.removeAll()
        
        // Timer for Wave Propagation
        // Radius 0 -> ~15 (Covering diagonal of 9x9 grid)
        // Duration: ~1.5 seconds total
        let step: CGFloat = 0.5
        let maxRadius: CGFloat = 15.0
        let interval: TimeInterval = 0.05
        
        waveTimer?.invalidate()
        waveTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                self.waveRadius += step
                
                // Check for mistakes revealed by the wave
                self.checkForRevealedMistakes()
                
                // Check Completion
                if self.waveRadius > maxRadius {
                    self.waveTimer?.invalidate()
                    self.waveTimer = nil
                    self.finalizeVictoryCheck()
                }
            }
        }
    }
    
    private func checkForRevealedMistakes() {
        guard let origin = waveOrigin else { return }
        let originRow = origin / 9
        let originCol = origin % 9
        
        let showMistakes = settings?.mistakeMode == .onFull
        
        if showMistakes {
            let radiusSq = waveRadius * waveRadius
            for i in 0..<cells.count {
                if !revealedMistakeIndices.contains(i) {
                    let r = i / 9
                    let c = i % 9
                    let dr = r - originRow
                    let dc = c - originCol
                    let distSq = CGFloat(dr * dr + dc * dc)
                    
                    if distSq <= radiusSq {
                        if i < solutionArray.count {
                            let cellValue = cells[i].value
                            if cellValue != 0 && cellValue != solutionArray[i] {
                                revealedMistakeIndices.insert(i)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func finalizeVictoryCheck() {
        // After wave completes, check if solved
        let currentString = cells.map { String($0.value) }.joined()
        if currentString == solution {
             completeGame()
        } else {
            // Wave finished, mistakes revealed. Game continues.
            isWaveActive = false 
        }
    }
    
    private func completeGame() {
        // Success!
        
        // 2. Stop Timer
        stopTimer()
        isTimerRunning = false // Explicitly ensure false as requested
        
        // 3. Update Progress
        isSolved = true
        parentViewModel.levelSolved(id: levelID, timeElapsed: timeElapsed)
        
        // Clear Last Unfinished Level
        UserDefaults.standard.set(-1, forKey: "lastUnfinishedLevelID")
        
        // 4. Persistence
        saveState()
        
        // 5. Trigger Completion Modal
        // Delay slightly for impact
         Task { @MainActor in
             try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
             isGameComplete = true
         }
        

    }
    
    func checkForWin(wasBoardFull: Bool = false) {
        // 1. Check if board is FULL
        let isFull = cells.allSatisfy { $0.value != 0 }
        
        // 2. Victory Check (Always performed if full)
        if isFull {
            let currentString = cells.map { String($0.value) }.joined()
            let isCorrect = currentString == solution
            
            if isCorrect {
                // VICTORY: Always trigger wave for celebration
                if let lastIndex = selectedCellIndex {
                     triggerVictoryWave(from: lastIndex)
                } else {
                     triggerVictoryWave(from: 40)
                }
            } else {
                // MISTAKES PRESENT:
                // Only trigger wave to reveal mistakes IF:
                // A) Board transitioned from Not Full -> Full (Users wants to see result of their last move)
                // B) It wasn't full before (Same as A)
                
                if !wasBoardFull {
                    if let lastIndex = selectedCellIndex {
                         triggerVictoryWave(from: lastIndex)
                    } else {
                         triggerVictoryWave(from: 40)
                    }
                }
            }
        }
    }
    
    // MARK: - Mistake Logic
    
    var isBoardFull: Bool {
        !cells.contains(where: { $0.value == 0 })
    }
    
    func isMistake(at index: Int) -> Bool {
        guard index < 81, index < cells.count else { return false }
        let cell = cells[index]
        if cell.value == 0 { return false }
        if isClue(at: index) { return false }
        
        // 1. Solution Check (O(1) array access)
        var isSolutionMismatch = false
        if index < solutionArray.count {
            isSolutionMismatch = cell.value != solutionArray[index]
        }
        
        // 2. Non-Consecutive Rule Check
        var isVariantViolation = false
        if isNonConsecutive || rules.contains(.nonConsecutive) {
            isVariantViolation = hasConsecutiveNeighbor(at: index, value: cell.value)
        }
        
        return isSolutionMismatch || isVariantViolation
    }
    
    var isNonConsecutive: Bool {
        return rules.contains(.nonConsecutive)
    }
    
    func hasConsecutiveNeighbor(at index: Int, value: Int) -> Bool {
        let row = index / 9
        let col = index % 9
        
        let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)] // Up, Down, Left, Right
        
        for (dr, dc) in directions {
            let r = row + dr
            let c = col + dc
            
            if r >= 0 && r < 9 && c >= 0 && c < 9 {
                let neighborIndex = r * 9 + c
                let neighborValue = cells[neighborIndex].value
                
                if neighborValue != 0 {
                     let diff = abs(neighborValue - value)
                     if diff == 1 {
                         return true
                     }
                }
            }
        }
        return false
    }
    
    func shouldShowMistake(at index: Int) -> Bool {
        // Default to .immediate if settings not loaded yet, or check legacy flag
        let mode = settings?.mistakeMode ?? .immediate
        
        if isMistake(at: index) {
            switch mode {
            case .never:
                return false
            case .immediate:
                return true
            case .onFull:
                return revealedMistakeIndices.contains(index)
            }
        }
        return false
    }

    private func boardStringToIntGrid(_ board: String) -> [[Int]] {
        var grid: [[Int]] = []
        let chars = Array(board)
        guard chars.count == 81 else { return [] }
        
        for row in 0..<9 {
            var rowValues: [Int] = []
            for col in 0..<9 {
                let index = row * 9 + col
                if let val = Int(String(chars[index])) {
                    rowValues.append(val)
                } else {
                    rowValues.append(0)
                }
            }
            grid.append(rowValues)
        }
        return grid
    }
    // MARK: - Highlighting Logic
    
    @Published var restrictedHighlightSet: Set<Int> = []
    
    private func updateRestrictions() {
        // Calculate common digit for Multi-Selection Highlight
        if selectedIndices.count > 1 {
            if let common = getCommonSelectedDigit() {
                explicitHighlightedDigit = common
            } else {
                explicitHighlightedDigit = nil
            }
        }
        
        // Only potential mode
        guard settings?.highlightMode == .potential else {
            restrictedHighlightSet = []
            return
        }
        
        // Get valid selected digit
        guard let anchor = selectedCellIndex, anchor < cells.count else {
            restrictedHighlightSet = []
            return
        }
        
        let cell = cells[anchor]
        let digit = cell.value
        if digit != 0 {
            // Run Pointing Pairs Solver
            restrictedHighlightSet = PointingPairsSolver.getPointedRestrictions(board: currentBoard, digit: digit)
        } else {
            restrictedHighlightSet = []
        }
    }
    
    // Helper to find if all selected cells share a common non-zero digit
    private func getCommonSelectedDigit() -> Int? {
        guard !selectedIndices.isEmpty else { return nil }
        
        var commonValue: Int? = nil
        
        for index in selectedIndices {
            let val = cells[index].value
            if val == 0 { return nil } // If any cell is empty, no common digit highlight
            
            if let existing = commonValue {
                if existing != val { return nil } // Mixed values
            } else {
                commonValue = val
            }
        }
        
        return commonValue
    }

    enum CellHighlightType {
        case selected       // The exact cell selected
        case sameValue      // Same value as selected cell
        case relating       // Same Box (or other minor relation)
        case none
    }
    
    func getHighlightType(at index: Int) -> CellHighlightType {
        if selectedIndices.contains(index) {
            return .selected
        }
        
        // Multi-Selection Clutter Reduction:
        // If multiple cells are selected, disable 'Same Number' and 'Relating' highlights for unselected cells.
        if selectedIndices.count > 1 {
            return .none
        }
        
        // 2. Logic based on Explicit Highlight (No Anchor needed)
        if let explicit = explicitHighlightedDigit {
             let val = getValueAt(index)
             if val != 0 && val == explicit {
                 return .sameValue
             }
             // No neighborhood highlighting for explicit number mode
             return .none
        }
        
        // 3. Logic based on PRIMARY selected intent (selectedCellIndex as active anchor)
        guard let anchor = selectedCellIndex else { return .none }
        
        let selectedValue = getValueAt(anchor)
        
        // GLOBAL HIGHLIGHTS (Applied regardless of Minimal/Restriction/Potential Mode)
        
        // a) Same Digit
        if selectedValue != 0 {
            if settings?.isHighlightSameNumberEnabled ?? true {
                let currentValue = getValueAt(index)
                if currentValue != 0 && currentValue == selectedValue {
                    return .sameValue
                }
            }
        } else {
             // b) Check for Note Highlighting (If selected cell is empty and has notes)
             if settings?.isHighlightSameNoteEnabled ?? true {
                 if index != anchor && index < cells.count && anchor < cells.count {
                     let anchorNotes = cells[anchor].notes
                     let currentNotes = cells[index].notes
                     
                     // If the selected cell has notes, and the current cell shares at least one note
                     if !anchorNotes.isEmpty && !anchorNotes.isDisjoint(with: currentNotes) {
                         return .relating // Use relating (subtle) for shared notes
                     }
                 }
             }
        }
        
        // If Minimal Mode is ON, we STOP here (no Neighborhood/Potential highlights)
        if settings?.isMinimalHighlight ?? true {
            return .none
        }
        
        let mode = settings?.highlightMode ?? .restriction // Use Setting mainly for 'Potential' vs 'Restriction' style neighborhood
        
        // 3. Logic based on Mode (Non-Minimal)
        
        // Standard "Restriction" style (Neighborhood + Same Value)
        
        if mode == .potential {
             // POTENTIAL MODE (If enabled in settings)
             if selectedValue != 0 {
                let digit = selectedValue
                let currentValue = getValueAt(index)
                
                if currentValue == 0 {
                    if isValid(digit, at: index, ignoring: -1) {
                         // Refined Logic (Non-Consecutive Potential)
                         // Check global property first or if rules contains .nonConsecutive
                         if isNonConsecutive || rules.contains(.nonConsecutive) {
                             if hasConsecutiveNeighbor(at: index, value: digit) {
                                 // Valid by Sudoku rules, but violates N±1
                                 return .none
                             }
                         }
                        
                        // Refined Logic (Odd-Even Potential)
                        if rules.contains(.oddEven), let parityString = parityOverlay, index < parityString.count {
                             let parityChar = parityString[parityString.index(parityString.startIndex, offsetBy: index)]
                             if parityChar == "1" && digit % 2 == 0 { return .none } // Odd cell: cannot place Even
                             if parityChar == "2" && digit % 2 != 0 { return .none } // Even cell: cannot place Odd
                        }
                        
                        // KNIGHT Constraint
                        if rules.contains(.knight) {
                            if hasKnightConflict(at: index, value: digit) { return .none }
                        }
                        
                        // KING Constraint
                        if rules.contains(.king) {
                            if hasKingConflict(at: index, value: digit) { return .none }
                        }
                        
                        // KROPKI Constraint
                        if rules.contains(.kropki) {
                            if hasKropkiConflict(at: index, value: digit) { return .none }
                        }
                        
                        // THERMO Constraint
                        if rules.contains(.thermo) {
                            if hasThermoConflict(at: index, value: digit) { return .none }
                        }
                        
                        // ARROW Constraint
                        if rules.contains(.arrow) {
                            if hasArrowConflict(at: index, value: digit) { return .none }
                        }
                        
                        // KILLER Constraint
                        if rules.contains(.killer) {
                            if hasKillerConflict(at: index, value: digit) { return .none }
                        }
                        
                        // Line-Box / Pointing Pairs Restriction
                        if pointPairRestrictions.contains(index) {
                            return .none
                        }
                        
                        
                        if restrictedHighlightSet.contains(index) {
                            return .none
                        }
                        
                        return .relating // Potential spot
                    }
                }
                // Same Value check moved up
            } else {
                 // Empty Cell in Potential Mode:
                 return .none
            }
        } else {
            // STANDARD / RESTRICTION (Legacy Default)
            
            // b) Neighborhood (Row, Col, Box)
            if isSameNeighborhood(index1: anchor, index2: index) {
                return .relating
            }
        }
        
        return .none
    }
    
    func isOrthogonalNeighbor(index1: Int, index2: Int) -> Bool {
        let r1 = index1 / 9
        let c1 = index1 % 9
        let r2 = index2 / 9
        return abs(r1 - r2) + abs(c1 - (index2 % 9)) == 1
    }

    // MARK: - Advanced Constraint Checks
    
    func hasKnightConflict(at index: Int, value: Int) -> Bool {
        let row = index / 9
        let col = index % 9
        let moves = HighlightManager.knightOffsets
        
        for move in moves {
            let nRow = row + move.0
            let nCol = col + move.1
            
            if nRow >= 0 && nRow < 9 && nCol >= 0 && nCol < 9 {
                let nIndex = nRow * 9 + nCol
                if getValueAt(nIndex) == value {
                    return true
                }
            }
        }
        return false
    }
    
    func hasKingConflict(at index: Int, value: Int) -> Bool {
        let row = index / 9
        let col = index % 9
        let moves = HighlightManager.kingOffsets
        
        for move in moves {
            let nRow = row + move.0
            let nCol = col + move.1
            
            if nRow >= 0 && nRow < 9 && nCol >= 0 && nCol < 9 {
                let nIndex = nRow * 9 + nCol
                if getValueAt(nIndex) == value {
                    return true
                }
            }
        }
        return false
    }
    
    func hasKropkiConflict(at index: Int, value: Int) -> Bool {
        let row = index / 9
        let col = index % 9
        let neighbors = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        
        for move in neighbors {
            let nRow = row + move.0
            let nCol = col + move.1
            
            if nRow >= 0 && nRow < 9 && nCol >= 0 && nCol < 9 {
                let nIndex = nRow * 9 + nCol
                let nVal = getValueAt(nIndex)
                
                if nVal > 0 {
                    let isWhiteConnected = hasDotConnection(type: .white, index1: index, index2: nIndex)
                    let isBlackConnected = hasDotConnection(type: .black, index1: index, index2: nIndex)
                    
                    if isWhiteConnected {
                        if abs(value - nVal) != 1 { return true }
                    }
                    
                    if isBlackConnected {
                        if value != nVal * 2 && nVal != value * 2 { return true }
                    }
                    
                    if negativeConstraint && !isWhiteConnected && !isBlackConnected {
                        if abs(value - nVal) == 1 { return true }
                        if value == nVal * 2 || nVal == value * 2 { return true }
                    }
                }
            }
        }
        return false
    }
    
    enum KropkiDotType { case white, black }
    
    private func hasDotConnection(type: KropkiDotType, index1: Int, index2: Int) -> Bool {
        // Normalize indices for easier checking (r1, c1, r2, c2)
        let r1 = index1 / 9; let c1 = index1 % 9
        let r2 = index2 / 9; let c2 = index2 % 9
        
        // Ensure consistent ordering for lookup (min -> max) to match stored dot struct if needed,
        // but our level dots might be stored in any order. Ideally we check both directions OR normalize.
        // Let's iterate the dot lists.
        
        let dots = (type == .white) ? (whiteDots ?? []) : (blackDots ?? [])
        
        for dot in dots {
            // Check if this dot connects (r1,c1) and (r2,c2)
            if (dot.r1 == r1 && dot.c1 == c1 && dot.r2 == r2 && dot.c2 == c2) ||
               (dot.r1 == r2 && dot.c1 == c2 && dot.r2 == r1 && dot.c2 == c1) {
                return true
            }
        }
        return false
    }

    // MARK: - Advanced Constraint Helpers
    
    func hasThermoConflict(at index: Int, value: Int) -> Bool {
        guard let paths = thermoPaths else { return false }
        
        for path in paths {
            let pathIndices = path.map { $0[0] * 9 + $0[1] }
            
            if let pos = pathIndices.firstIndex(of: index) {
                if pos > 0 {
                    let prevVal = getValueAt(pathIndices[pos - 1])
                    if prevVal != 0 && prevVal >= value {
                        return true
                    }
                }
                
                if pos < path.count - 1 {
                    let nextVal = getValueAt(pathIndices[pos + 1])
                    if nextVal != 0 && nextVal <= value {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    func hasArrowConflict(at index: Int, value: Int) -> Bool {
        guard let arrowList = arrows else { return false }
        
        for arrow in arrowList {
            let bulbIndex = arrow.bulb[0] * 9 + arrow.bulb[1]
            let lineIndices = arrow.line.map { $0[0] * 9 + $0[1] }
            
            if bulbIndex == index {
                var currentSum = 0
                var isFullyFilled = true
                for lineIdx in lineIndices {
                    let v = getValueAt(lineIdx)
                    if v != 0 {
                        currentSum += v
                    } else {
                        isFullyFilled = false
                    }
                }
                
                if isFullyFilled {
                    if currentSum != value { return true }
                } else {
                    if value < currentSum { return true }
                }
            }
            
            if let linePos = lineIndices.firstIndex(of: index) {
                let bulbSum = getValueAt(bulbIndex)
                if bulbSum != 0 {
                    var lineSum = value
                    for (i, lineIdx) in lineIndices.enumerated() {
                        if i == linePos { continue }
                        let v = getValueAt(lineIdx)
                        if v != 0 {
                            lineSum += v
                        }
                    }
                    
                    if lineSum > bulbSum { return true }
                }
            }
        }
        return false
    }
    
    func hasKillerConflict(at index: Int, value: Int) -> Bool {
        guard let cageList = cages else { return false }
        
        for cage in cageList {
            let cageIndices = cage.cells.map { $0[0] * 9 + $0[1] }
            
            if cageIndices.contains(index) {
                // 1. Check Uniqueness within Cage
                for otherIdx in cageIndices {
                    if otherIdx == index { continue }
                    if getValueAt(otherIdx) == value { return true }
                }
                
                // 2. Check Sum Constraint
                let targetSum = cage.sum
                var currentCageSum = value
                var isFullyFilled = true
                
                for otherIdx in cageIndices {
                    if otherIdx == index { continue }
                    let v = getValueAt(otherIdx)
                    if v != 0 {
                        currentCageSum += v
                    } else {
                        isFullyFilled = false
                    }
                }
                
                if isFullyFilled {
                    if currentCageSum != targetSum { return true }
                } else {
                    if currentCageSum > targetSum { return true }
                }
            }
        }
        return false
    }
    
    // Helper for Neighborhood (Row, Col, Box)
    private func isSameNeighborhood(index1: Int, index2: Int) -> Bool {
        let row1 = index1 / 9
        let col1 = index1 % 9
        let boxRow1 = row1 / 3
        let boxCol1 = col1 / 3
        
        let row2 = index2 / 9
        let col2 = index2 % 9
        let boxRow2 = row2 / 3
        let boxCol2 = col2 / 3
        
        // Row or Col
        if row1 == row2 || col1 == col2 { return true }
        // Box
        if boxRow1 == boxRow2 && boxCol1 == boxCol2 { return true }
        
        // Knight's Move Neighborhood
        if rules.contains(.knight) {
            let dr = abs(row1 - row2)
            let dc = abs(col1 - col2)
            if (dr == 1 && dc == 2) || (dr == 2 && dc == 1) {
                 return true
            }
        }
        
        // King's Move Neighborhood
        if rules.contains(.king) {
            let dr = abs(row1 - row2)
            let dc = abs(col1 - col2)
            if dr <= 1 && dc <= 1 && !(dr == 0 && dc == 0) {
                 return true
            }
        }
        
        return false
    }
    
    private func getCharAt(_ index: Int) -> Character {
        guard index < currentBoardArray.count else { return "0" }
        return Character(String(currentBoardArray[index]))
    }
    
    /// O(1) integer value lookup — preferred over getCharAt for numeric comparisons
    private func getValueAt(_ index: Int) -> Int {
        guard index < currentBoardArray.count else { return 0 }
        return currentBoardArray[index]
    }
    
    private func isSameBox(index1: Int, index2: Int) -> Bool {
        let row1 = index1 / 9
        let col1 = index1 % 9
        let boxRow1 = row1 / 3
        let boxCol1 = col1 / 3
        
        let row2 = index2 / 9
        let col2 = index2 % 9
        let boxRow2 = row2 / 3
        let boxCol2 = col2 / 3
        
        return boxRow1 == boxRow2 && boxCol1 == boxCol2
    }
    
    func isValid(_ number: Int, at index: Int, ignoring ignoredIndex: Int) -> Bool {
        let row = index / 9
        let col = index % 9
        let boxRow = row / 3
        let boxCol = col / 3
        
        for i in 0..<81 {
            if i == index || i == ignoredIndex { continue }
            
            let val = currentBoardArray[i]
            if val == 0 { continue }
            
            if val == number {
                let r = i / 9
                let c = i % 9
                let br = r / 3
                let bc = c / 3
                
                if r == row || c == col || (br == boxRow && bc == boxCol) {
                    return false
                }
                
                if rules.contains(.knight) {
                    let dr = abs(r - row)
                    let dc = abs(c - col)
                    if (dr == 1 && dc == 2) || (dr == 2 && dc == 1) {
                         return false
                    }
                }
                
                if rules.contains(.king) {
                    let dr = abs(r - row)
                    let dc = abs(c - col)
                    if dr <= 1 && dc <= 1 && !(dr == 0 && dc == 0) {
                         return false
                    }
                }
            }
        }
        return true
    }
    

    // MARK: - Timer Logic
    @Published var isPaused: Bool = false
    @Published var isSettingsPresented: Bool = false
    @Published var isRulesPresented: Bool = false
    
    var shouldRunTimer: Bool {
        !isPaused && !isSettingsPresented && !isRulesPresented && !isGameComplete
    }
    
    func startTimer() {
        guard !isSolved else { return }
        if timer == nil {
            isTimerRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    if self.shouldRunTimer {
                        self.timeElapsed += 1
                        
                        // Wave Effect Update
                        if self.isWaveActive {
                           withAnimation(.linear(duration: 1.0)) {
                               self.waveRadius += 1.5 // Expand wave
                           }
                           if self.waveRadius > 20 { // Max radius
                               self.isWaveActive = false
                               self.waveRadius = 0
                           }
                        }
                    }
                }
            }
        }
    }
    
    func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
        saveState()
    }
    
    var formattedTime: String {
        let hours = timeElapsed / 3600
        let minutes = (timeElapsed % 3600) / 60
        let seconds = timeElapsed % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Header Info
    var levelTitle: String {
        "Level \(levelID)"
    }
    
    func getRawRuleType() -> String {
         if let level = parentViewModel.levels.first(where: { $0.id == levelID }) {
             return level.ruleType.rawValue
         }
         return "classic"
    }

    var gameTypeInfo: (text: String, icon: String, rule: String) {
         // Get ruleType from level (from parent VM is safest source of truth for metadata)
         if let level = parentViewModel.levels.first(where: { $0.id == levelID }) {
             let type = level.ruleType
             let typeName = type.displayName.uppercased().replacingOccurrences(of: " SUDOKU", with: "") + " SUDOKU"
             return (typeName, type.iconName, type.displayName.replacingOccurrences(of: " Sudoku", with: ""))
         }
        return ("UNKNOWN", "questionmark.square", "Classic")
    }
    
    // MARK: - Undo / Redo Logic
    
    var canUndo: Bool {
        historyIndex >= 0
    }
    
    var canRedo: Bool {
        guard let progress = levelProgress, let moves = progress.moves else { return false }
        return historyIndex < moves.count - 1
    }
    
    private func addMove(cellIndex: Int, moveType: String, oldValue: String?, newValue: String?, batchID: UUID? = nil, performSave: Bool = true) {
        guard let progress = levelProgress else { return }
        
        // OPTIMIZATION: Check if we are appending to the end (Common Case)
        // If so, avoid sorting the entire history.
        let movesCount = progress.moves?.count ?? 0
        let isAtEnd = historyIndex == movesCount - 1
        
        var newOrder = 0
        
        if isAtEnd {
            // Appending: No truncation needed.
            // Just find max orderIndex. (O(N) scan on Set is faster than O(N log N) sort)
            if let moves = progress.moves, !moves.isEmpty {
                 // Optimization: If we track historyIndex, that maps to orderIndex if linear?
                 // But safer to just scan.
                 let maxOrder = moves.map { $0.orderIndex }.max() ?? -1
                 newOrder = maxOrder + 1
            } else {
                newOrder = 0
            }
        } else {
            // Forking History: Must sort and truncate
            let currentMoves = (progress.moves ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
            
            // Delete forward history
            if historyIndex < currentMoves.count - 1 {
                let movesToDelete = currentMoves.suffix(from: historyIndex + 1)
                for move in movesToDelete {
                    parentViewModel.modelContext?.delete(move)
                    if let idx = progress.moves?.firstIndex(of: move) {
                        progress.moves?.remove(at: idx)
                    }
                }
            }
            
            var lastOrder = -1
            // Re-calculate last order after deletion (Optimization: use historyIndex directly?)
            // If historyIndex is 5, the move at index 5 has order X. We want X+1.
            // But let's trust the remaining set.
            if historyIndex >= 0 && historyIndex < currentMoves.count {
                 lastOrder = currentMoves[historyIndex].orderIndex
            }
            newOrder = lastOrder + 1
        }
        
        // Create New Move
        let move = MoveHistory(orderIndex: newOrder, cellIndex: cellIndex, moveType: moveType, oldValue: oldValue, newValue: newValue, batchID: batchID)
        
        parentViewModel.modelContext?.insert(move)
        progress.moves?.append(move)
        
        historyIndex += 1
        
        if performSave {
            saveState()
        }
    }
    
    func undo() {
        guard let progress = levelProgress else { return }
        
        let wasFullStart = isBoardFull
        
        let sortedMoves = (progress.moves ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
        
        guard historyIndex >= 0 && historyIndex < sortedMoves.count else { return }
        
        // Helper
        func performUndo(_ move: MoveHistory) {
            applyChange(moveType: move.moveType, cellIndex: move.cellIndex, value: move.oldValue)
            historyIndex -= 1
        }
        
        let move = sortedMoves[historyIndex]
        let currentBatchID = move.batchID
        
        performUndo(move)
        
        // Batch Logic
        if let batchID = currentBatchID {
            while historyIndex >= 0 {
                let prevMove = sortedMoves[historyIndex]
                if prevMove.batchID == batchID {
                    performUndo(prevMove)
                } else {
                    break
                }
            }
        }
        
        finishBatchUpdate(checkWin: true, wasBoardFull: wasFullStart)
    }
    
    func redo() {
        guard let progress = levelProgress else { return }
        
        let wasFullStart = isBoardFull
        
        let sortedMoves = (progress.moves ?? []).sorted(by: { $0.orderIndex < $1.orderIndex })
        
        guard historyIndex < sortedMoves.count - 1 else { return }
        
        // Helper
        func performRedo(_ move: MoveHistory) {
            applyChange(moveType: move.moveType, cellIndex: move.cellIndex, value: move.newValue)
            historyIndex += 1
        }
        
        let nextIndex = historyIndex + 1
        let move = sortedMoves[nextIndex]
        let currentBatchID = move.batchID
        
        performRedo(move)
        
        // Batch Logic
        if let batchID = currentBatchID {
            while historyIndex < sortedMoves.count - 1 {
                let nextMove = sortedMoves[historyIndex + 1]
                if nextMove.batchID == batchID {
                    performRedo(nextMove)
                } else {
                    break
                }
            }
        }
        
        finishBatchUpdate(checkWin: true, wasBoardFull: wasFullStart)
    }
    
    @MainActor
    private func applyChange(moveType: String, cellIndex: Int, value: String?) {
        guard cellIndex >= 0 && cellIndex < cells.count else { return }
        let cell = cells[cellIndex]
        let val = value ?? ""
        
        switch moveType {
        case "Value":
            let intVal = Int(val) ?? 0
            cell.value = intVal

            // Clear revealed state on Undo/Redo of Value
            revealedMistakeIndices.remove(cellIndex)

            // Sync currentBoard string implicitly? 
            // Better to let saveState handle it, or update it here if used elsewhere.
            // But cells is source of truth now.
            
        case "Note":
            if val.isEmpty {
                cell.notes = []
            } else {
                let noteInts = val.split(separator: ",").compactMap { Int($0) }
                cell.notes = Set(noteInts)
            }
            
        case "Color":
            if val == "clear" || val.isEmpty {
                cell.color = nil
            } else if let colorInt = Int(val) {
                cell.color = colorInt
            }
            
        case "Cross":
            cell.hasCross = (val == "true")
        
        default:
            break
        }
    }

    // MARK: - Restart Logic
    func restartLevel() {
        // Enforce MainActor logic with explicit Task if called from elsewhere, 
        // though func is on @MainActor class.
        // We wrap to ensure precise scheduling sequence.
        Task { @MainActor in
            self.stopTimer()
            self.timeElapsed = 0
            self.isSolved = false
            self.isGameComplete = false
            
            // Reset Board
            if let level = parentViewModel.levels.first(where: { $0.id == levelID }) {
                // Restore original board (ignoring progress)
                self.currentBoard = level.board ?? String(repeating: "0", count: 81)
                self.notes = [:]
                self.cellColors = [:]
                self.cellCrosses = [:]
                
                // Clear History & Persistence
                // We delegate this to parentViewModel to ensure both In-Memory 'levels' array and 'SwiftData' are synced.
                self.parentViewModel.resetLevelProgress(levelID: self.levelID)
                
                // Also manually clear local reference to ensure safety
                if let progress = self.levelProgress {
                    // Delete Moves (Synchronously) - handled here or in parent? 
                    // Parent resetLevelProgress clears fields, but we need to delete Moves explicitly if they are a relationship.
                    // Let's do moves here to be safe and keep logic close to 'MoveHistory' knowledge.
                     if let moves = progress.moves {
                        for move in moves {
                            self.parentViewModel.modelContext?.delete(move)
                        }
                        progress.moves?.removeAll()
                    }
                    self.historyIndex = -1
                }
                
                // Re-Initialize Cells
                self.initializeCells()
                self.checkKropkiErrors()
                
                self.startTimer()
                
                // Force UI Redraw
                self.boardID = UUID()
                self.objectWillChange.send()
            }
        }
    }


    func checkKropkiErrors() {
        guard negativeConstraint else {
            if !kropkiErrors.isEmpty { kropkiErrors = [] }
            return
        }
        
        var errors: Set<KropkiBorder> = []
        let currentString = currentBoard
        let wDots = whiteDots ?? []
        let bDots = blackDots ?? []
        
        // Helper to check for dot existence
        func hasDot(r1: Int, c1: Int, r2: Int, c2: Int) -> Bool {
            // Check White
            for dot in wDots {
                if (dot.r1 == r1 && dot.c1 == c1 && dot.r2 == r2 && dot.c2 == c2) { return true }
                if (dot.r1 == r2 && dot.c1 == c2 && dot.r2 == r1 && dot.c2 == c1) { return true }
            }
            // Check Black
            for dot in bDots {
                if (dot.r1 == r1 && dot.c1 == c1 && dot.r2 == r2 && dot.c2 == c2) { return true }
                if (dot.r1 == r2 && dot.c1 == c2 && dot.r2 == r1 && dot.c2 == c1) { return true }
            }
            return false
        }
        // Use cached integer array for speed
        let boardArray = currentBoardArray
        func getVal(r: Int, c: Int) -> Int {
            let idx = r * 9 + c
            if idx >= 0 && idx < boardArray.count {
                return boardArray[idx]
            }
            return 0
        }
        
        // Horizontal Checks
        for r in 0..<9 {
            for c in 0..<8 {
                // If NO dot exists
                if !hasDot(r1: r, c1: c, r2: r, c2: c+1) {
                    let v1 = getVal(r: r, c: c)
                    let v2 = getVal(r: r, c: c+1)
                    
                    if v1 != 0 && v2 != 0 {
                        // Check violations
                        let diff = abs(v1 - v2)
                        let isConsecutive = (diff == 1)
                        let isRatio = (v1 == 2 * v2) || (v2 == 2 * v1)
                        
                        if isConsecutive || isRatio {
                            errors.insert(KropkiBorder(r1: r, c1: c, r2: r, c2: c+1))
                        }
                    }
                }
            }
        }
        
        // Vertical Checks
        for r in 0..<8 {
            for c in 0..<9 {
                // If NO dot exists
                if !hasDot(r1: r, c1: c, r2: r+1, c2: c) {
                    let v1 = getVal(r: r, c: c)
                    let v2 = getVal(r: r+1, c: c)
                    
                    if v1 != 0 && v2 != 0 {
                        // Check violations
                        let diff = abs(v1 - v2)
                        let isConsecutive = (diff == 1)
                        let isRatio = (v1 == 2 * v2) || (v2 == 2 * v1)
                        
                        if isConsecutive || isRatio {
                            errors.insert(KropkiBorder(r1: r, c1: c, r2: r+1, c2: c))
                        }
                    }
                }
            }
        }
        
        if kropkiErrors != errors {
            kropkiErrors = errors
        }
    }
}
