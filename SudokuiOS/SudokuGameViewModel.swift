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
    var isClue: Bool
    var parity: String?
    
    init(id: Int, row: Int? = nil, col: Int? = nil, value: Int, notes: Set<Int> = [], color: Int? = nil, hasCross: Bool = false, isClue: Bool, parity: String? = nil) {
        self.id = id
        self.value = value
        self.notes = notes
        self.color = color
        self.hasCross = hasCross
        self.isClue = isClue
        self.parity = parity
    }
}

@MainActor
class SudokuGameViewModel: ObservableObject {
    let levelID: Int
    private var parentViewModel: LevelViewModel
    var levelViewModel: LevelViewModel { parentViewModel } // Expose for View access
    
    /// Custom levels use unique negative IDs (from UUID hash)
    var isCustomLevel: Bool { levelID < 0 }
    
    // Game State
    @Published var currentBoard: String = ""
    private(set) var currentBoardArray: [Int] = Array(repeating: 0, count: 81)
    @Published var selectedCellIndex: Int?
    @Published var isSolved: Bool = false
    @Published var isGameComplete: Bool = false 
    @Published var customLevelUUID: String? = nil
    @Published var customLevelTitle: String? = nil
    @Published var showCustomBoardError: Bool = false
    
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
    @Published var markedCombinations: [String: Set<[Int]>] = [:] // Key: ClueID (Sandwich)
    
    // Killer Helper State
    @Published var selectedCage: SudokuLevel.Cage?
    @Published var markedKillerCombinations: [String: Set<[Int]>] = [:] // Key: Cage Top-Left coordinate string "r,c"
    @Published var isKillerHelperPresented: Bool = false
    
    // Explicit Highlight (Number Pad Toggle)
    @Published var explicitHighlightedDigit: Int? = nil
    
    // Completed Digits Tracking
    @Published var completedDigits: Set<Int> = []
    
    func selectClue(index: Int, isRow: Bool, sum: Int) {
        let id = isRow ? "Row-\(index)" : "Col-\(index)"
        
        // Return if helpers are disabled in settings
        if settings?.isCombinationHelperEnabled == false {
            return
        }
        
        // Auto-Selection Logic: If no state exists for this clue, select ALL valid combinations by default.
        if markedCombinations[id] == nil {
             let allCombos = SandwichMath.getSandwichCombinations(for: sum, rules: rules)
             markedCombinations[id] = Set(allCombos)
             applyCombinationAutoFilter()
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
    
    func dismissKillerHelper() {
        isKillerHelperPresented = false
    }
    
    func toggleKillerCombination(_ combination: [Int]) {
        guard let cage = selectedCage, let topLeft = cage.topLeft else { return }
        let cageID = "\(topLeft[0]),\(topLeft[1])"
        
        var currentSet = markedKillerCombinations[cageID] ?? []
        if currentSet.contains(combination) {
            currentSet.remove(combination)
        } else {
            currentSet.insert(combination)
        }
        markedKillerCombinations[cageID] = currentSet        
        applyCombinationAutoFilter()
        saveState()
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
        
        applyCombinationAutoFilter()
        // Save immediately
        saveState()
    }
    
    // Highlight Settings
    // Uses settings reference
    
    // History
    var historyIndex: Int = -1 
    
    var levelProgress: UserLevelProgress? 
    
    var settings: AppSettings? {
        didSet {
            // When settings change, re-apply auto-filter logic
            applyCombinationAutoFilter()
        }
    }
    
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
    @Published var bestTime: Double = 0.0
    
    // New Gameplay Mechanics
    @Published var mistakesCount: Int = 0
    @Published var hintsUsed: Int = 0
    @Published var isGameOver = false
    @Published var hintCooldownRemaining: Int = 0 // Seconds
    private var hintCooldownTimer: Timer?
    @Published var showHintErrorAlert: Bool = false
    var hintErrorMessage: String = ""
    @Published var isRewardedAdLoading: Bool = false
    

    
    @Published var kropkiErrors: Set<KropkiBorder> = []
    
    // Palette (Versa Style - 9 Curated Pastel Colors)
    static let palette: [Color] = [
        Color(hex: "#FFB3BA"), // Pastel Red/Pink
        Color(hex: "#FFDFBA"), // Pastel Orange
        Color(hex: "#FFFFBA"), // Pastel Yellow
        Color(hex: "#B8F2E6"), // Pastel Mint
        Color(hex: "#BAE1FF"), // Pastel Blue
        Color(hex: "#E2CBF7"), // Pastel Purple
        Color(hex: "#F5D5CB"), // Pastel Peach
        Color(hex: "#D0F4DE"), // Pastel Green
        Color(hex: "#E2E2E2")  // Pastel Gray/Silver
    ]
    
    var cellCrosses: [Int: Bool] = [:] // Temporary storage during init
    
    init(levelID: Int, levelViewModel: LevelViewModel, session: GameSession? = nil, title: String? = nil) {
        self.levelID = levelID
        self.parentViewModel = levelViewModel
        self.customLevelTitle = title
        
        loadLevelData(session: session)
        
        // Track Game Session for Persistence
        saveGameSession()
        
        // Resume any active hint cooldown
        startHintCooldownTimer()
    }
    
    init(level: SudokuLevel, levelViewModel: LevelViewModel, session: GameSession? = nil, title: String? = nil) {
        self.levelID = level.id
        self.parentViewModel = levelViewModel
        self.customLevelTitle = title ?? level.customTitle
        
        self.setupLevel(level, session: session)
        
        // Track Game Session for Persistence
        saveGameSession()
        
        // Resume any active hint cooldown
        startHintCooldownTimer()
    }
    
    private func loadLevelData(session: GameSession? = nil) {
        // Ensure data is loaded in parent
        if parentViewModel.levels.isEmpty {
            parentViewModel.loadLevelsFromJSON()
        }
        
        // Find the level (Standard or Injected Custom)
        guard let level = parentViewModel.levels.first(where: { $0.id == levelID }) else {
            loadEmptyBoard()
            return
        }
        
        setupLevel(level, session: session)
    }
    
    private func setupLevel(_ level: SudokuLevel, session: GameSession? = nil) {
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
        self.bestTime = level.bestTime
        self.customLevelUUID = level.customUUID
        self.customLevelTitle = level.customTitle
        
        self.ruleType = level.ruleType
        // Hybrid Support: Use 'types' if available, otherwise fallback to single 'ruleType'
        if !level.types.isEmpty {
            self.rules = level.types
        } else {
            self.rules = [level.ruleType]
        }
        
        // 2. Set Current State (Session > User Progress > Static Board)
        if let session = session, let board = session.userBoard {
            self.currentBoard = board
            self.timeElapsed = session.timeElapsed
        } else if let progress = level.userProgress {
            self.currentBoard = progress
            self.timeElapsed = level.timeElapsed
        } else {
            self.currentBoard = initialBoard
            self.timeElapsed = 0
        }
        
        self.currentBoardArray = Self.parseBoardString(self.currentBoard)
        
        // 4. Reset Gameplay Stats
        self.mistakesCount = 0
        self.hintsUsed = 0
        self.isGameOver = false
        self.hintCooldownRemaining = 0
        self.hintCooldownTimer?.invalidate()
        
        // 5. Load Notes (Prioritize Session)
        let resolvedNotesData = (session?.notesData != nil) ? session?.notesData : level.notesData
        if let notesData = resolvedNotesData {
            if let decodedStringNotes = try? JSONDecoder().decode([String: Set<Int>].self, from: notesData) {
                self.notes = Dictionary(uniqueKeysWithValues: decodedStringNotes.compactMap { (key, val) in
                    guard let intKey = Int(key) else { return nil }
                    return (intKey, val)
                })
            } else if let decodedNotes = try? JSONDecoder().decode([Int: Set<Int>].self, from: notesData) {
                self.notes = decodedNotes
            }
        }
        
        // 5b. Load Colors (Prioritize Session)
        let resolvedColorData = (session?.colorData != nil) ? session?.colorData : level.colorData
        if let colorData = resolvedColorData {
             if let decodedStringColors = try? JSONDecoder().decode([String: Int].self, from: colorData) {
                 self.cellColors = Dictionary(uniqueKeysWithValues: decodedStringColors.compactMap { (key, val) in
                     guard let intKey = Int(key) else { return nil }
                     return (intKey, val)
                 })
             } else if let decodedColors = try? JSONDecoder().decode([Int: Int].self, from: colorData) {
                 self.cellColors = decodedColors
             }
        }
        
        // 6. Load Marked Combinations (Prioritize Session)
        let resolvedComboData = (session?.markedCombinationsData != nil) ? session?.markedCombinationsData : level.markedCombinationsData
        if let comboData = resolvedComboData {
            if let decodedCombos = try? JSONDecoder().decode([String: Set<[Int]>].self, from: comboData) {
                self.markedCombinations = decodedCombos
            }
        }
        
        // 6b. Load Marked Killer Combinations (Prioritize Session)
        let resolvedKillerComboData = (session?.killerMarkedCombinationsData != nil) ? session?.killerMarkedCombinationsData : level.killerMarkedCombinationsData
        if let killerComboData = resolvedKillerComboData {
            if let decodedKillerCombos = try? JSONDecoder().decode([String: Set<[Int]>].self, from: killerComboData) {
                self.markedKillerCombinations = decodedKillerCombos
            }
        }

        
        // 7. Load Cross Data (Prioritize Session)
        let resolvedCrossData = (session?.crossData != nil) ? session?.crossData : level.crossData
        if let crossData = resolvedCrossData {
             if let decodedCrosses = try? JSONDecoder().decode([Int: Bool].self, from: crossData) {
                 self.cellCrosses = decodedCrosses
             }
        }
        
        // 5. Load Persistent Object for History (Move History, Undo/Redo)
        if let progress = parentViewModel.getProgress(for: levelID) {
            self.levelProgress = progress
            if let moves = progress.moves, !moves.isEmpty {
                self.historyIndex = moves.count - 1
            }
        } else {
            // First time this level is played, create empty progress record for history
            if let context = parentViewModel.modelContext {
                let newProgress = UserLevelProgress(levelID: levelID, isSolved: self.isSolved)
                newProgress.currentUserBoard = self.currentBoard
                context.insert(newProgress)
                self.levelProgress = newProgress
                self.historyIndex = -1
                try? context.save()
            }
        }
        
        // 6. Initialize Observable Cells
        initializeCells()
        applyCombinationAutoFilter() // Apply filter after loading all data
    }
    
    @Published var cells: [SudokuCellModel] = []
    
    private func loadEmptyBoard() {
        self.initialBoard = String(repeating: "0", count: 81)
        self.solution = ""
        self.initialBoardArray = Array(repeating: 0, count: 81)
        self.solutionArray = Array(repeating: 0, count: 81)
        self.currentBoard = self.initialBoard
        self.ruleType = .classic
        self.rules = [.classic]
        self.timeElapsed = 0
        self.mistakesCount = 0
        self.hintsUsed = 0
        self.isGameOver = false
        self.hintCooldownRemaining = 0
        self.hintCooldownTimer?.invalidate()
        self.cells = (0..<81).map { SudokuCellModel(id: $0, row: $0/9, col: $0%9, value: 0, isClue: false) }
    }
    
    private func finishLoadingBoardSetup() {
        initializeCells()
        applyCombinationAutoFilter()
    }
    
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
            let row = i / 9
            let col = i % 9
            let cellParity = self.parityOverlay?[i] ?? "0"
            let cellParityVal: String? = (cellParity == "1" || cellParity == "2") ? String(cellParity) : nil
            
            newCells.append(SudokuCellModel(
                id: i,
                row: row,
                col: col,
                value: val,
                notes: n,
                color: c,
                hasCross: cross,
                isClue: clue,
                parity: cellParityVal
            ))
        }
        self.cells = newCells
        recalculateCompletedDigits()
        
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
    
    func saveGameSession() {
        guard let level = parentViewModel.levels.first(where: { $0.id == levelID }) else { return }
        
        var session = GameSession(
            levelID: levelID,
            isCustomLevel: isCustomLevel,
            customLevelId: customLevelUUID
        )
        
        // State Persistence: Capture current board string and metadata
        var chars = [Character]()
        chars.reserveCapacity(81)
        var notesDict: [String: Set<Int>] = [:]
        var colorsDict: [String: Int] = [:]
        var crossesDict: [Int: Bool] = [:]
        
        for cell in cells {
            chars.append(Character(String(cell.value)))
            if !cell.notes.isEmpty { notesDict[String(cell.id)] = cell.notes }
            if let color = cell.color { colorsDict[String(cell.id)] = color }
            if cell.hasCross { crossesDict[cell.id] = true }
        }
        
        session.userBoard = String(chars)
        session.notesData = try? JSONEncoder().encode(notesDict)
        session.colorData = try? JSONEncoder().encode(colorsDict)
        session.markedCombinationsData = try? JSONEncoder().encode(markedCombinations)
        session.killerMarkedCombinationsData = try? JSONEncoder().encode(markedKillerCombinations)
        session.crossData = try? JSONEncoder().encode(crossesDict)
        session.timeElapsed = timeElapsed
        
        let sessionKey = isCustomLevel ? "active_custom_session" : "active_standard_session"
        
        // --- NEW: For custom levels, we only need to store the POINTER (UUID) and Mode in UserDefaults ---
        // The actual board data is now stored directly on CustomSudokuLevel in SwiftData.
        if !isCustomLevel {
            if let encoded = try? JSONEncoder().encode(session) {
                UserDefaults.standard.set(encoded, forKey: sessionKey)
            }
        } else {
            // Optional: clear the old heavy session data to save memory
            UserDefaults.standard.removeObject(forKey: "active_custom_session")
        }
        
        // Track last played mode for "Continue" logic
        UserDefaults.standard.set(isCustomLevel ? "custom" : "standard", forKey: "lastPlayedMode")
        
        // Legacy Cleanup/Sync (Optional but kept for compatibility if needed elsewhere)
        UserDefaults.standard.set(levelID, forKey: "lastUnfinishedLevelID")
        UserDefaults.standard.set(session.timestamp, forKey: "lastPlayedTimestamp")
         if let uuid = level.customUUID {
             UserDefaults.standard.set(uuid, forKey: "lastCustomLevelUUID")
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
        let killerMarkedCombinationsData = try? JSONEncoder().encode(markedKillerCombinations)
        let crossData = try? JSONEncoder().encode(crossesDict)
        
        parentViewModel.saveLevelProgress(levelId: levelID, customUUID: customLevelUUID, currentBoard: currentBoardString, notesData: notesData, colorData: colorData, markedCombinationsData: markedCombinationsData, killerMarkedCombinationsData: killerMarkedCombinationsData, crossData: crossData, timeElapsed: timeElapsed)
        
        // Also update Active Game Session (UserDefaults) to ensure "Continue" routing is accurate
        saveGameSession()
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
        updateSelectedCage()
    }
    
    private func updateSelectedCage() {
        guard let index = selectedCellIndex else {
            selectedCage = nil
            return
        }
        
        let row = index / 9
        let col = index % 9
        
        // Find if this cell belongs to any killer cage
        let newCage = cages?.first(where: { cage in
            cage.cells.contains { $0 == [row, col] }
        })
        
        if let cage = newCage {
            let topLeft = cage.topLeft ?? [0,0]
            let cageID = "\(topLeft[0]),\(topLeft[1])"
            
            // Auto-Selection Logic: If no state exists for this cage, select ALL valid combinations by default.
            if markedKillerCombinations[cageID] == nil {
                let allCombos = KillerMath.getCombinations(sum: cage.sum, count: cage.cells.count, rules: rules, cageCells: cage.cells)
                markedKillerCombinations[cageID] = Set(allCombos)
                applyCombinationAutoFilter() // Apply filter immediately after setting defaults
                saveState() // Instant persistence for defaults
            }
        }
        
        selectedCage = newCage
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
        updateSelectedCage()
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
        updateSelectedCage()
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
        updateSelectedCage()
    }
    
    func toggleMultiSelectMode() {
        isMultiSelectMode.toggle()
    }
    
    func toggleSelectAllEmptyCells() {
        let emptyIndices = cells.filter { $0.value == 0 }.map { $0.id }
        guard !emptyIndices.isEmpty else { return }
        
        let allEmptySelected = emptyIndices.allSatisfy { selectedIndices.contains($0) }
        
        if allEmptySelected {
            for index in emptyIndices {
                selectedIndices.remove(index)
            }
        } else {
            isMultiSelectMode = true
            for index in emptyIndices {
                selectedIndices.insert(index)
            }
            selectedCellIndex = emptyIndices.last
        }
        
        updateRestrictions()
        triggerHaptic()
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
    
    func toggleCrossAllEmptyCells() {
        let emptyIndices = cells.filter { $0.value == 0 }.map { $0.id }
        guard !emptyIndices.isEmpty else { return }
        
        let batchID = UUID()
        let shouldAdd = emptyIndices.contains { !cells[$0].hasCross }
        
        for index in emptyIndices {
            let cell = cells[index]
            if cell.hasCross != shouldAdd {
                let oldValue = cell.hasCross ? "true" : "false"
                let newValue = shouldAdd ? "true" : "false"
                
                addMove(cellIndex: index, moveType: "Cross", oldValue: oldValue, newValue: newValue, batchID: batchID, performSave: false)
                
                cell.hasCross = shouldAdd
            }
        }
        finishBatchUpdate()
        triggerHaptic()
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
        
        finishBatchUpdate()
        applyCombinationAutoFilter()
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
                
                // Add move history BEFORE value change
                addMove(cellIndex: index, moveType: "Value", oldValue: oldValue, newValue: newValue, batchID: batchID, performSave: false)
                
                // --- Mistake Check Logic ---
                // Skip solution-based mistakes for custom levels (no solution data)
                if !isCustomLevel {
                    let isLimitEnabled = settings?.isMistakeLimitEnabled ?? true
                    if targetValue != 0 && isLimitEnabled {
                        let isIncorrect = targetValue != solutionArray[index]
                        if isIncorrect {
                            // It's a mistake!
                            mistakesCount += 1
                            
                            // Check Game Over
                            if mistakesCount >= 3 {
                                DispatchQueue.main.async {
                                    self.isGameOver = true
                                    self.stopTimer()
                                }
                            }
                            
                            // We do NOT stop entering the value, it still gets placed
                            // The UI will highlight it as red depending on the mistakeMode setting.
                        }
                    }
                }
                // ---------------------------
                
                // 3. Auto-Pruning Hook (If setting a value)
                if targetValue != 0 {
                    autoPruneNotes(for: index, value: targetValue, batchID: batchID)
                }
            }
        }
        
        // 2. Force SwiftData to save and notify observers immediately
        // 2. Force SwiftData to save and notify observers immediately
        finishBatchUpdate()
        applyCombinationAutoFilter()
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
        applyCombinationAutoFilter()
        
        // Trigger UI Pulse to ensure views switch from Value to Note mode instantly
        self.objectWillChange.send()
    }
    
    
    private func recalculateCompletedDigits() {
        var counts = [Int: Int]()
        for cell in cells {
            if cell.value != 0 {
                counts[cell.value, default: 0] += 1
            }
        }
        
        var completed = Set<Int>()
        for digit in 1...9 {
            if counts[digit, default: 0] == 9 {
                completed.insert(digit)
            }
        }
        
        if self.completedDigits != completed {
            self.completedDigits = completed
        }
    }
    
    private func finishBatchUpdate(checkWin: Bool = false, wasBoardFull: Bool = false) {
        recalculateCompletedDigits()
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
    func didTap19() {
        if selectedCellIndex == nil && selectedIndices.isEmpty {
            return // Ignore if no cell is selected, as "19" is a multi-digit note action.
        }
        
        let batchID = UUID()
        let validIndices = selectedIndices.filter { cells[$0].value == 0 }
        
        guard !validIndices.isEmpty else { return }
        
        // Context Check for each valid cell
        var cellsContext: [(index: Int, canPlace1: Bool, canPlace9: Bool)] = []
        for index in validIndices {
            cellsContext.append((
                index: index,
                canPlace1: isValid(1, at: index, ignoring: -1),
                canPlace9: isValid(9, at: index, ignoring: -1)
            ))
        }
        
        // Determine whether to Add or Remove globally for the batch
        // If ANY valid cell is missing a *possible* 1 or 9, we ADD
        let shouldAdd = cellsContext.contains { ctx in
            let cell = cells[ctx.index]
            let missing1 = ctx.canPlace1 && !cell.notes.contains(1)
            let missing9 = ctx.canPlace9 && !cell.notes.contains(9)
            return missing1 || missing9
        }
        
        for ctx in cellsContext {
            let cell = cells[ctx.index]
            
            var currentNotes = cell.notes
            let oldNotesString = currentNotes.sorted().map{String($0)}.joined(separator: ",")
            
            if shouldAdd {
                if ctx.canPlace1 { currentNotes.insert(1) }
                if ctx.canPlace9 { currentNotes.insert(9) }
            } else {
                if ctx.canPlace1 { currentNotes.remove(1) }
                if ctx.canPlace9 { currentNotes.remove(9) }
            }
            
            // Routinely clear out impossible notes just in case
            if !ctx.canPlace1 { currentNotes.remove(1) }
            if !ctx.canPlace9 { currentNotes.remove(9) }
            
            let newNotesString = currentNotes.sorted().map{String($0)}.joined(separator: ",")
            
            if oldNotesString != newNotesString {
                cell.notes = currentNotes
                addMove(cellIndex: ctx.index, moveType: "Note", oldValue: oldNotesString, newValue: newNotesString, batchID: batchID, performSave: false)
            }
        }
        
        finishBatchUpdate()
        self.objectWillChange.send() // Trigger UI Pulse
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
        guard !isCustomLevel else { return } // No solution to compare
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
    
    // MARK: - Combination Auto-Filtering
    
    func applyCombinationAutoFilter() {
        guard settings?.isAutoFilterCombinationsEnabled == true else { return }
        
        var changed = false
        
        // 1. Sandwich Auto-Filtering
        for (clueID, markedSet) in markedCombinations {
            let (isRow, index) = parseClueID(clueID)
            let gapDigits = getSandwichGapDigits(isRow: isRow, index: index)
            
            if !gapDigits.isEmpty {
                let filteredSet = markedSet.filter { combo in
                    gapDigits.allSatisfy { combo.contains($0) }
                }
                
                if filteredSet != markedSet {
                    markedCombinations[clueID] = filteredSet
                    changed = true
                }
            }
        }
        
        // 2. Killer Auto-Filtering
        if let cageList = cages {
            for (cagePos, markedSet) in markedKillerCombinations {
                guard let cage = cageList.first(where: { 
                    if let tl = $0.topLeft {
                        return "\(tl[0]),\(tl[1])" == cagePos
                    }
                    return false
                }) else { continue }
                let cageDigits = getCageDigits(cage: cage)
                
                if !cageDigits.isEmpty {
                    let filteredSet = markedSet.filter { combo in
                        cageDigits.allSatisfy { combo.contains($0) }
                    }
                    
                    if filteredSet != markedSet {
                        markedKillerCombinations[cagePos] = filteredSet
                        changed = true
                    }
                }
            }
        }
        
        if changed {
            saveState()
            objectWillChange.send()
        }
    }
    
    private func parseClueID(_ id: String) -> (isRow: Bool, index: Int) {
        let components = id.split(separator: "-")
        let isRow = components[0] == "Row"
        let index = Int(components[1]) ?? 0
        return (isRow, index)
    }
    
    private func getSandwichGapDigits(isRow: Bool, index: Int) -> Set<Int> {
        var digits = Set<Int>()
        var indices: [Int] = []
        
        if isRow {
            indices = (0..<9).map { index * 9 + $0 }
        } else {
            indices = (0..<9).map { $0 * 9 + index }
        }
        
        let boardValues = indices.map { cells[$0].value }
        guard let first19 = boardValues.firstIndex(where: { $0 == 1 || $0 == 9 }),
              let last19 = boardValues.lastIndex(where: { $0 == 1 || $0 == 9 }),
              first19 != last19 else {
            return []
        }
        
        for i in (first19 + 1)..<last19 {
            let val = boardValues[i]
            if val > 1 && val < 9 {
                digits.insert(val)
            }
        }
        
        return digits
    }
    
    private func getCageDigits(cage: SudokuLevel.Cage) -> Set<Int> {
        var digits = Set<Int>()
        for r in 0..<9 {
            for c in 0..<9 {
                if cage.cells.contains(where: { $0[0] == r && $0[1] == c }) {
                    let val = cells[r * 9 + c].value
                    if val != 0 {
                        digits.insert(val)
                    }
                }
            }
        }
        return digits
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
        
        // Update local best time for victory screen
        let currentTotalSeconds = Double(timeElapsed)
        if bestTime == 0 || currentTotalSeconds < bestTime {
            bestTime = currentTotalSeconds
        }
        
        let isPerfect = (mistakesCount == 0 && hintsUsed == 0)
        let customUUID = self.customLevelUUID ?? parentViewModel.levels.first(where: { $0.id == levelID })?.customUUID
        parentViewModel.levelSolved(id: levelID, customUUID: customUUID, timeElapsed: timeElapsed, isPerfect: isPerfect, mistakesMade: mistakesCount)
        
        // 3b. Clear Custom Level Progress if applicable
        if isCustomLevel, let uuidString = customUUID, let uuid = UUID(uuidString: uuidString) {
             let context = parentViewModel.modelContext
             let descriptor = FetchDescriptor<CustomSudokuLevel>(predicate: #Predicate<CustomSudokuLevel> { level in
                 level.id == uuid
             })
             if let customLevel = try? context?.fetch(descriptor).first {
                 customLevel.savedBoardProgress = nil
                 customLevel.savedNotesData = nil
                 customLevel.savedColorData = nil
                 customLevel.savedMarkedCombinationsData = nil
                 customLevel.savedKillerMarkedCombinationsData = nil
                 customLevel.savedCrossData = nil
                 customLevel.savedTime = 0
                 try? context?.save()
             }
        }
        
        // Clear Active Game Session
        UserDefaults.standard.removeObject(forKey: "activeGameSession")
        UserDefaults.standard.set(-1, forKey: "lastUnfinishedLevelID") // Legacy Cleanup
        
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
        
        // 2. Victory Check
        if isFull {
            if isCustomLevel {
                // Custom Level: No solution array, must validate mathematically
                let validator = SudokuValidator()
                let boardMatrix = (0..<9).map { r in
                    (0..<9).map { c in cells[r * 9 + c].value }
                }
                
                if validator.validate(board: boardMatrix, rules: activeRules) {
                    // Valid Solution found!
                    if let lastIndex = selectedCellIndex {
                        triggerVictoryWave(from: lastIndex)
                    } else {
                        triggerVictoryWave(from: 40)
                    }
                } else {
                    // Board is full but invalid
                    showCustomBoardError = true
                }
            } else {
                // Standard Level: Check against pre-calculated solution
                let currentString = cells.map { String($0.value) }.joined()
                let isCorrect = currentString == solution
                
                if isCorrect {
                    if let lastIndex = selectedCellIndex {
                        triggerVictoryWave(from: lastIndex)
                    } else {
                        triggerVictoryWave(from: 40)
                    }
                } else if !wasBoardFull {
                    // revealed mistakes only on first transition to full
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
        
        // 1. Solution Check (skip for custom levels — no solution data)
        var isSolutionMismatch = false
        if !isCustomLevel, index < solutionArray.count {
            isSolutionMismatch = cell.value != solutionArray[index]
        }
        
        // 2. Non-Consecutive Rule Check (keep for all levels)
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
    
    // MARK: - Hints
    
    @MainActor
    func useHint(storeManager: StoreManager, adCoordinator: AdCoordinator) {
        guard !isGameOver && !isSolved else { return }
        
        // 1. Check user preference
        let appliesToSelected = UserDefaults.standard.bool(forKey: "hintAppliesToSelectedCell")
        
        var targetIndex: Int? = nil
        
        if appliesToSelected {
            // Selected Cell Logic
            guard let selected = selectedIndices.first, selectedIndices.count == 1 else {
                hintErrorMessage = "Please select an empty cell to use a hint."
                showHintErrorAlert = true
                return
            }
            if cells[selected].value == solutionArray[selected] {
                hintErrorMessage = "The selected cell is already correct!"
                showHintErrorAlert = true
                return
            }
            if isClue(at: selected) {
                hintErrorMessage = "You cannot use a hint on a given clue."
                showHintErrorAlert = true
                return
            }
            targetIndex = selected
        } else {
            // Random Cell Logic
            var candidates: [Int] = []
            for i in 0..<81 {
                if cells[i].value == 0 || cells[i].value != solutionArray[i] {
                    // Don't override clues
                    if !isClue(at: i) {
                        candidates.append(i)
                    }
                }
            }
            targetIndex = candidates.randomElement()
        }
        
        guard let validTargetIndex = targetIndex else { return }
        
        let applyHint = {
            self.hintsUsed += 1
            let correctValue = self.solutionArray[validTargetIndex]
            
            // Apply it via batch to handle note pruning, etc.
            self.selectedIndices = [validTargetIndex]
            
            // Bypass note mode for hint application
            let wasNoteMode = self.isNoteMode
            self.isNoteMode = false
            
            // Only toggle the cell if we need to insert the value
            // Since it's incorrect or empty, we just force enter the correct number
            if self.cells[validTargetIndex].value != 0 {
                // Clear incorrect value first
                self.enterNumber(self.cells[validTargetIndex].value)
            }
            self.enterNumber(correctValue)
            
            self.isNoteMode = wasNoteMode
            // Keep the cell selected for convenience
            // self.selectedIndices = []
        }
        
        if storeManager.isAdsRemoved {
            // Premium Cooldown (5 minutes = 300 seconds)
            applyHint()
            startPersistentHintCooldown()
        } else {
            // Rewarded Ad
            self.isRewardedAdLoading = true
            adCoordinator.showRewardedVideo { success in
                DispatchQueue.main.async {
                    self.isRewardedAdLoading = false
                    if success {
                        applyHint()
                        self.startPersistentHintCooldown() // 5 minute persistent cooldown for all users
                    }
                }
            }
        }
    }
    
    private func startPersistentHintCooldown() {
        let duration: TimeInterval = 300 // 5 minutes
        let targetDate = Date().addingTimeInterval(duration)
        UserDefaults.standard.set(targetDate, forKey: "nextHintAvailableDate")
        startHintCooldownTimer()
    }
    
    private func startHintCooldownTimer() {
        hintCooldownTimer?.invalidate()
        
        // Initial check
        updateCooldownRemaining()
        guard hintCooldownRemaining > 0 else { return }
        
        hintCooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateCooldownRemaining()
            }
        }
    }
    
    private func updateCooldownRemaining() {
        guard let targetDate = UserDefaults.standard.object(forKey: "nextHintAvailableDate") as? Date else {
            hintCooldownRemaining = 0
            hintCooldownTimer?.invalidate()
            return
        }
        
        let remaining = Int(targetDate.timeIntervalSinceNow)
        if remaining > 0 {
            hintCooldownRemaining = remaining
        } else {
            hintCooldownRemaining = 0
            hintCooldownTimer?.invalidate()
            UserDefaults.standard.removeObject(forKey: "nextHintAvailableDate")
        }
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
        case sameNote       // Shares the same note or has note that matches selected value
        case relating       // Same Box (or other minor relation)
        case sameNoteAndRelating // NEW: Represents a cell that has a matching note AND is restricted/potential
        case none
    }
    
    func getHighlightType(at index: Int) -> CellHighlightType {
        if selectedIndices.contains(index) {
            return .selected
        }
        
        var isSameNoteMatch = false // MUST BE AT THE TOP
        
        // 2. Logic based on Explicit Highlight (No Anchor needed)
        if let explicit = explicitHighlightedDigit {
             let val = getValueAt(index)
             
             // Highlight matching numbers
             if val != 0 && val == explicit {
                 if settings?.isHighlightSameNumberEnabled ?? true {
                     return .sameValue
                 }
             }
             
             // Highlight matching notes
             if val == 0 && (settings?.isHighlightSameNoteEnabled ?? true) {
                 if cells[index].notes.contains(explicit) {
                     isSameNoteMatch = true // Set flag, do not return yet!
                 }
             }

             // If it's a pure explicit highlight (1 or 0 cells selected), stop here.
             // If multiple cells are selected, allow it to fall through to the intersection logic!
             if selectedIndices.count <= 1 {
                 return isSameNoteMatch ? .sameNote : .none
             }
        }
        
        var selectedValue: Int = 0
        if let anchor = selectedCellIndex, anchor < cells.count {
             selectedValue = cells[anchor].value
        }
        
        // Single Selection specific logic
        if selectedIndices.count == 1 {
            // a) Same Digit
            if selectedValue != 0 {
                let currentValue = getValueAt(index)
                
                if currentValue != 0 && currentValue == selectedValue {
                    if settings?.isHighlightSameNumberEnabled ?? true {
                        return .sameValue
                    }
                } else if currentValue == 0 && cells[index].notes.contains(selectedValue) {
                    if settings?.isHighlightSameNoteEnabled ?? true {
                        isSameNoteMatch = true
                    }
                }
            } else {
                 // b) Check for Note Highlighting (If selected cell is empty and has notes)
                 if settings?.isHighlightSameNoteEnabled ?? true {
                     if let anchor = selectedCellIndex, index != anchor && index < cells.count && anchor < cells.count {
                         let anchorNotes = cells[anchor].notes
                         let currentNotes = cells[index].notes
                         
                         // If the selected cell has notes, and the current cell shares at least one note
                         if !anchorNotes.isEmpty && !anchorNotes.isDisjoint(with: currentNotes) {
                             isSameNoteMatch = true // Set flag, do not return yet
                         }
                     }
                 }
            }
        }
        
        // If Minimal Mode is ON, we STOP here (no Neighborhood/Potential highlights)
        if settings?.isMinimalHighlight ?? true {
            return isSameNoteMatch ? .sameNote : .none
        }
        
        let mode = settings?.highlightMode ?? .restriction // Use Setting mainly for 'Potential' vs 'Restriction' style neighborhood
        
        // 3. Logic based on Mode (Non-Minimal)
        if mode == .potential && selectedIndices.count <= 1 {
            // POTENTIAL MODE (If enabled in settings)
            if selectedIndices.count == 1 && selectedValue != 0 {
                let digit = selectedValue
                let cellValue = getValueAt(index)
                
                if cellValue == 0 {
                    if !isValid(digit, at: index, ignoring: -1) { return isSameNoteMatch ? .sameNote : .none }
                    if isNonConsecutive || rules.contains(.nonConsecutive) {
                        if hasConsecutiveNeighbor(at: index, value: digit) { return isSameNoteMatch ? .sameNote : .none }
                    }
                    if rules.contains(.kropki) {
                        if hasKropkiConflict(at: index, value: digit) { return isSameNoteMatch ? .sameNote : .none }
                    }
                    if rules.contains(.thermo) {
                        if hasThermoConflict(at: index, value: digit) { return isSameNoteMatch ? .sameNote : .none }
                    }
                    if rules.contains(.arrow) {
                        if hasArrowConflict(at: index, value: digit) { return isSameNoteMatch ? .sameNote : .none }
                    }
                    if rules.contains(.killer) {
                        if hasKillerConflict(at: index, value: digit) { return isSameNoteMatch ? .sameNote : .none }
                    }
                    if pointPairRestrictions.contains(index) { return isSameNoteMatch ? .sameNote : .none }
                    if restrictedHighlightSet.contains(index) { return isSameNoteMatch ? .sameNote : .none }
                    
                    return isSameNoteMatch ? .sameNoteAndRelating : .relating // Potential spot
                }
            }
        } else {
            // STANDARD / RESTRICTION (Legacy Default)
            guard !selectedIndices.isEmpty else { return isSameNoteMatch ? .sameNote : .none }
            
            let isRestrictedByAll = selectedIndices.allSatisfy { selectedIndex in
                isSameNeighborhood(index1: selectedIndex, index2: index)
            }
            
            if isRestrictedByAll {
                return isSameNoteMatch ? .sameNoteAndRelating : .relating
            }
        }
        
        return isSameNoteMatch ? .sameNote : .none
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
        applyCombinationAutoFilter()
        saveState()
    }
    
    var formattedTime: String {
        let hours = timeElapsed / 3600
        let minutes = (timeElapsed % 3600) / 60
        let seconds = timeElapsed % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    var levelTitle: String {
        if isCustomLevel {
            return customLevelTitle ?? "Custom Level"
        }
        return "Level \(levelID)"
    }
    
    // Bridge rules for SudokuValidator
    var activeRules: [SudokuRule] {
        var results: [SudokuRule] = [.classic]
        
        let rowCluesOptional = rowClues?.map { $0 as Int? } ?? Array(repeating: nil, count: 9)
        let colCluesOptional = colClues?.map { $0 as Int? } ?? Array(repeating: nil, count: 9)
        
        for rule in rules {
            switch rule {
            case .sandwich:
                results.append(.sandwich(rows: rowCluesOptional, cols: colCluesOptional))
            case .arrow:
                results.append(.arrow(arrows ?? []))
            case .thermo:
                results.append(.thermo(paths: thermoPaths ?? []))
            case .killer:
                results.append(.killer(cages ?? []))
            case .kropki:
                results.append(.kropki(white: whiteDots ?? [], black: blackDots ?? [], negativeConstraint: negativeConstraint))
            case .oddEven:
                results.append(.oddEven(parity: parityOverlay ?? ""))
            case .knight:
                results.append(.knight)
            case .king:
                results.append(.king)
            case .nonConsecutive:
                results.append(.nonConsecutive)
            case .classic:
                break
            }
        }
        
        // Handle single rule fallback
        if rules.isEmpty, let singleRule = ruleType {
            switch singleRule {
            case .sandwich: results.append(.sandwich(rows: rowCluesOptional, cols: colCluesOptional))
            case .arrow: results.append(.arrow(arrows ?? []))
            case .thermo: results.append(.thermo(paths: thermoPaths ?? []))
            case .killer: results.append(.killer(cages ?? []))
            case .kropki: results.append(.kropki(white: whiteDots ?? [], black: blackDots ?? [], negativeConstraint: negativeConstraint))
            case .oddEven: results.append(.oddEven(parity: parityOverlay ?? ""))
            case .knight: results.append(.knight)
            case .king: results.append(.king)
            case .nonConsecutive: results.append(.nonConsecutive)
            case .classic: break
            }
        }
        
        return results
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
        
        applyCombinationAutoFilter()
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
        
        applyCombinationAutoFilter()
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
            
            // Reset New Gameplay Stats
            self.mistakesCount = 0
            self.hintsUsed = 0
            self.isGameOver = false
            self.startHintCooldownTimer() // Ensure it continues running if active            
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
                
                // Clear Selections
                self.selectedIndices.removeAll()
                self.selectedCage = nil
                self.isKillerHelperPresented = false
                
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
