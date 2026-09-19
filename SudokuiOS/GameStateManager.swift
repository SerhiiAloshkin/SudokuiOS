import Foundation
import Combine

/// Manages core game state separate from UI concerns
/// Extracts state management from SudokuGameViewModel
@MainActor
final class GameStateManager: ObservableObject {
    
    // MARK: - Core State
    
    @Published var currentBoard: String = ""
    @Published var currentBoardArray: [Int] = Array(repeating: 0, count: 81)
    @Published var selectedCellIndex: Int?
    @Published var isSolved: Bool = false
    @Published var isGameComplete: Bool = false
    @Published var isGameOver: Bool = false
    @Published var isPaused: Bool = false
    
    // MARK: - Level Data
    
    let levelID: Int
    var isCustomLevel: Bool { levelID < 0 }
    var customLevelUUID: String?
    var customLevelTitle: String?
    
    var initialBoard: String = ""
    var initialBoardArray: [Int] = Array(repeating: 0, count: 81)
    private(set) var solution: String = ""
    private(set) var solutionArray: [Int] = Array(repeating: 0, count: 81)
    
    // MARK: - Rules & Constraints
    
    @Published var rules: [SudokuRuleType] = []
    var ruleType: SudokuRuleType?
    var isNonConsecutive: Bool = false
    
    // Variant data
    var rowClues: [Int]?
    var colClues: [Int]?
    var thermoPaths: [[[Int]]]?
    var cages: [SudokuLevel.Cage]?
    var arrows: [SudokuLevel.Arrow]?
    var whiteDots: [SudokuLevel.KropkiDot]?
    var blackDots: [SudokuLevel.KropkiDot]?
    var negativeConstraint: Bool = false
    var parityOverlay: String?
    
    // MARK: - Game Metrics
    
    @Published var timeElapsed: Int = 0
    @Published var mistakesCount: Int = 0
    @Published var hintsUsed: Int = 0
    var bestTime: Double = 0.0
    
    // MARK: - Multi-Select
    
    @Published var isMultiSelectMode: Bool = false
    @Published var selectedIndices: Set<Int> = []
    
    // MARK: - Initialization
    
    init(levelID: Int) {
        self.levelID = levelID
    }
    
    // MARK: - Board Operations
    
    func updateBoard(_ board: String) {
        self.currentBoard = board
        self.currentBoardArray = parseBoardString(board)
    }
    
    func updateBoardArray(_ array: [Int]) {
        self.currentBoardArray = array
        self.currentBoard = boardArrayToString(array)
    }
    
    func getValueAt(_ index: Int) -> Int {
        guard index >= 0 && index < currentBoardArray.count else { return 0 }
        return currentBoardArray[index]
    }
    
    func setValueAt(_ index: Int, value: Int) {
        guard index >= 0 && index < 81 else { return }
        var array = currentBoardArray
        array[index] = value
        updateBoardArray(array)
    }
    
    func isClue(at index: Int) -> Bool {
        guard index >= 0 && index < initialBoardArray.count else { return false }
        return initialBoardArray[index] != 0
    }
    
    // MARK: - State Checks
    
    func isBoardComplete() -> Bool {
        return currentBoardArray.allSatisfy { $0 != 0 }
    }
    
    func isBoardCorrect() -> Bool {
        guard !solutionArray.isEmpty else { return false }
        return currentBoardArray == solutionArray
    }
    
    // MARK: - Reset
    
    func resetToInitial() {
        updateBoard(initialBoard)
        timeElapsed = 0
        mistakesCount = 0
        hintsUsed = 0
        isSolved = false
        isGameComplete = false
        isGameOver = false
        selectedCellIndex = nil
        selectedIndices.removeAll()
    }
    
    // MARK: - Parsing Helpers
    
    private func parseBoardString(_ s: String) -> [Int] {
        var result = [Int](repeating: 0, count: 81)
        var i = 0
        for ch in s {
            guard i < 81 else { break }
            result[i] = ch.wholeNumberValue ?? 0
            i += 1
        }
        return result
    }
    
    private func boardArrayToString(_ array: [Int]) -> String {
        return array.map { String($0) }.joined()
    }
}
