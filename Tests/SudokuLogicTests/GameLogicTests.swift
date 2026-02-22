import XCTest
import SwiftData
@testable import SudokuLogic
import SwiftUI

@MainActor
final class GameLogicTests: XCTestCase {
    
    var container: ModelContainer!
    var levelViewModel: LevelViewModel!
    var gameViewModel: SudokuGameViewModel!
    
    override func setUp() async throws {
        // Setup in-memory stack
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, configurations: config)
        levelViewModel = LevelViewModel(modelContext: container.mainContext)
        
        // Ensure Level 1 is loaded (from JSON or mock)
        // Level 1 Board: "435269781682571493197834562826195347374682915951743628519326874248957136763418259"
        // (Just a mock pattern for testing logic)
        // Let's rely on JSON loading which happens in init.
        
        gameViewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
    }
    
    func testClueIsImmutable() {
        // Find a cell that is a clue (non-"0")
        guard let index = gameViewModel.currentBoard.firstIndex(where: { $0 != "0" }) else {
            XCTFail("Level 1 should have clues")
            return
        }
        let intIndex = gameViewModel.currentBoard.distance(from: gameViewModel.currentBoard.startIndex, to: index)
        let clueValue = String(gameViewModel.currentBoard[index])
        
        gameViewModel.selectCell(intIndex)
        
        // Attempt to change to something else (e.g. if clue is '1', try '2')
        let targetVal = clueValue == "1" ? 2 : 1
        gameViewModel.didTapNumber(targetVal)
        
        // Verify no change
        let newVal = gameViewModel.cells[intIndex].value
        XCTAssertEqual(String(newVal), clueValue, "Clue at index \(intIndex) should remain '\(clueValue)'")
    }
    
    func testInputUpdatesBoard() async {
        // Find an empty cell ('0')
        // In Level 1 JSON, indices might vary. Let's find first '0'.
        // If loaded correctly, Level 1 has 0s.
        guard let index = gameViewModel.currentBoard.firstIndex(of: "0") else {
            XCTFail("Level 1 should have empty cells for testing")
            return
        }
        let intIndex = gameViewModel.currentBoard.distance(from: gameViewModel.currentBoard.startIndex, to: index)
        
        // Select it
        gameViewModel.selectCell(intIndex)
        
        // Tap '9'
        gameViewModel.didTapNumber(9)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify update
        XCTAssertEqual(gameViewModel.cells[intIndex].value, 9, "Empty cell should accept input")
    }
    
    func testSolutionVerification() async {
        // Mock a specific simple board state for testing solution logic
        // We can't easily mock the internal 'level' of ViewModel without editing LevelViewModel.
        // Instead, we can create a GameViewModel for a synthetic level if our init allowed injection.
        // Since it fetches from LevelViewModel, let's inject a solved level into LevelViewModel.
        
        // Use a real valid solution because Validator checks logic now.
        let solvedBoard = "435269781682571493197834562826195347374682915951743628519326874248957136763418259"
        var initialBoardChars = Array(solvedBoard)
        initialBoardChars[0] = "0" // key: make index 0 editable
        let initialBoard = String(initialBoardChars)
        
        // Use ID 1000 to avoid conflict with default 1-600 range
        let level1000 = SudokuLevel(id: 1000, isLocked: false, isSolved: false, board: initialBoard, solution: solvedBoard)
        levelViewModel.levels.append(level1000)
        
        let testVM = SudokuGameViewModel(levelID: 1000, levelViewModel: levelViewModel)
        
        // It starts solved? No, currentBoard loads from board.
        // Let's modify currentBoard to have one '0' and then fill it.
        var almostSolved = Array(solvedBoard)
        almostSolved[0] = "0"
        testVM.currentBoard = String(almostSolved)
        
        // Select 0
        testVM.selectCell(0)
        
        // Tap '4' (Correct for this board)
        testVM.didTapNumber(4)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify Solved
        XCTAssertTrue(testVM.isSolved, "Board should be solved")
        XCTAssertTrue(levelViewModel.levels.last?.isSolved ?? false, "LevelViewModel should be updated")
    }
    
    func testLevelStructureAndRules() {
        // Load Level 1 (Classic Milestone)
        guard let level1 = levelViewModel.levels.first(where: { $0.id == 1 }) else {
            XCTFail("Level 1 not found")
            return
        }
        XCTAssertEqual(level1.ruleType, "classic", "Level 1 should be 'classic'")
        XCTAssertEqual(level1.board?.count, 81, "Level 1 should have valid board")
        let clues1 = level1.board?.filter { $0 != "0" }.count ?? 0
        XCTAssertEqual(clues1, 36, "Level 1 should have 36 clues")
        
        // Load Level 2 (Pending)
        guard let level2 = levelViewModel.levels.first(where: { $0.id == 2 }) else { return }
        XCTAssertEqual(level2.ruleType, "pending", "Level 2 should be 'pending'")
        XCTAssertTrue(level2.board?.isEmpty ?? true, "Level 2 board should be empty")
        
        // Load Level 11 (Next Milestone)
        guard let level11 = levelViewModel.levels.first(where: { $0.id == 11 }) else { return }
        XCTAssertEqual(level11.ruleType, "classic", "Level 11 should be 'classic'")
        let clues11 = level11.board?.filter { $0 != "0" }.count ?? 0
        // Target is 35. It might be +/- 1 depending on generation luck, but script aims for strict.
        // Let's assert equality for now as script uses strict mode.
        XCTAssertEqual(clues11, 35, "Level 11 should have 35 clues")
        
        // Load Level 41 (Milestone 4 -> 36-4 = 32)
        guard let level41 = levelViewModel.levels.first(where: { $0.id == 41 }) else { return }
        let clues41 = level41.board?.filter { $0 != "0" }.count ?? 0
        XCTAssertEqual(clues41, 32, "Level 41 should have 32 clues")
    }
    
    func testNoteModeSeparation() async {
        // Find empty cell
        // We need a board where we can write. Level 1 works.
        guard let index = gameViewModel.currentBoard.firstIndex(of: "0") else { return }
        let intIndex = gameViewModel.currentBoard.distance(from: gameViewModel.currentBoard.startIndex, to: index)
        
        gameViewModel.selectCell(intIndex)
        let initialChar = gameViewModel.currentBoard.first
        
        // 1. Enter Note
        gameViewModel.isNoteMode = true
        gameViewModel.didTapNumber(5)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(gameViewModel.cells[intIndex].notes.contains(5), "Note '5' should be added")
        // Check board didn't change (still '0')
        XCTAssertEqual(gameViewModel.cells[intIndex].value, 0, "Board should not change in note mode")
        
        // 2. Toggle Note off
        gameViewModel.didTapNumber(5)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertFalse(gameViewModel.cells[intIndex].notes.contains(5), "Note '5' should be removed")
        
        // 3. Enter Permanent
        gameViewModel.isNoteMode = false
        gameViewModel.didTapNumber(5)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(gameViewModel.cells[intIndex].value, 5, "Board should update in permanent mode")
    }
    

    
    func testColorMarking() {
        let index = 2
        gameViewModel.selectCell(index)
        gameViewModel.setCellColor(7) // Index 7 (Blue)
        
        XCTAssertEqual(gameViewModel.cells[index].color, 7)
    }

    func testStaticValidationSuccess() async {
        // 1. Defined Solution
        let solution = "435269781682571493197834562826195347374682915951743628519326874248957136763418259"
        
        // 2. Setup Board close to solution
        var nearComplete = Array(solution)
        nearComplete[80] = "0"
        let board = String(nearComplete)
        
        // Setup new level
        let levelID = 2000
        let customLevel = SudokuLevel(id: levelID, isLocked: false, isSolved: false, board: board, solution: solution)
        levelViewModel.levels.append(customLevel)
        let vm = SudokuGameViewModel(levelID: levelID, levelViewModel: levelViewModel)
        
        // User fills last cell
        vm.selectCell(80)
        vm.didTapNumber(Int(String(solution.last!))!)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        XCTAssertTrue(vm.isSolved, "Board should be solved when matching solution string")
    }
    
    func testStaticValidationFailure() async {
        let solution = "435269781682571493197834562826195347374682915951743628519326874248957136763418259"
        
        // Create wrong attempt
        var wrong = Array(solution)
        wrong[80] = "1" // Assume solution ends in 9
        let lastCharIndex = solution.index(before: solution.endIndex)
        if solution[lastCharIndex] == "1" { wrong[80] = "2" } 
        
        // Setup board (almost full of WRONG data? No, full of wrong data)
        // We need to trigger input.
        let target = wrong[80]
        wrong[80] = "0"
        let board = String(wrong)
        
        let levelID = 2001
        let customLevel = SudokuLevel(id: levelID, isLocked: false, isSolved: false, board: board, solution: solution)
        levelViewModel.levels.append(customLevel)
        let vm = SudokuGameViewModel(levelID: levelID, levelViewModel: levelViewModel)
        
        vm.selectCell(80)
        vm.didTapNumber(Int(String(target))!)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Should NOT be solved because it doesn't match solution string
        XCTAssertFalse(vm.isSolved, "Validator should reject board not matching solution")
    }
    func testContextualLogic() {
        // Test geometric relationships without needing view
        // Ensure Minimal Mode is OFF for this test
        let settings = SettingsViewModel()
        settings.isMinimalHighlight = false
        gameViewModel.settings = settings
        
        // Select index 0 (Row 0, Col 0, Box 0)
        gameViewModel.selectCell(0)
        
        // 1. Check Same Row (Index 8 is Row 0, Col 8)
        // In Restriction Mode, Row/Col outside box are NOT highlighted.
        XCTAssertEqual(gameViewModel.getHighlightType(at: 8), .none, "Same Row (outside box) should be none in Restriction Mode")
        
        // 2. Check Same Col (Index 72 is Row 8, Col 0)
        XCTAssertEqual(gameViewModel.getHighlightType(at: 72), .none, "Same Col (outside box) should be none in Restriction Mode")
        
        // 3. Check Same Box (Index 10 is Row 1, Col 1 -> Box 0)
        XCTAssertEqual(gameViewModel.getHighlightType(at: 10), .relating, "Same Box should be relating")
        
        // 4. Check Unrelated (Index 80 is Row 8, Col 8 -> Box 8)
        XCTAssertEqual(gameViewModel.getHighlightType(at: 80), .none, "Unrelated cell should be none")
        
        // 5. Check Selected (Index 0)
        XCTAssertEqual(gameViewModel.getHighlightType(at: 0), .selected, "Selected cell should be selected")
    }
    func testWinLogicUpdatesTimerAndPersistence() async {
        // 1. Setup Validation: Use a simplified custom level to rely on known solution
        let solution = "435269781682571493197834562826195347374682915951743628519326874248957136763418259"
        
        // Almost complete board (missing last char)
        var nearComplete = Array(solution)
        nearComplete[80] = "0"
        let board = String(nearComplete)
        
        let levelID = 3000
        let customLevel = SudokuLevel(id: levelID, isLocked: false, isSolved: false, board: board, solution: solution)
        levelViewModel.levels.append(customLevel)
        let vm = SudokuGameViewModel(levelID: levelID, levelViewModel: levelViewModel)
        
        // 2. Start Timer
        vm.startTimer()
        vm.timeElapsed = 100 // Simulate 100s elapsed
        XCTAssertTrue(vm.isTimerRunning, "Timer should be running")
        
        // 3. User Input: Complete Level
        vm.selectCell(80)
        vm.didTapNumber(Int(String(solution.last!))!)
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // 4. Assert Logic
        XCTAssertTrue(vm.isSolved, "Board should be solved")
        XCTAssertTrue(vm.isGameComplete, "UI State should clearly indicate success")
        XCTAssertFalse(vm.isTimerRunning, "Timer should STOP immediately on win")
        
        // 5. Assert Persistence (Wait for MainActor propagation if async? VM is actor.)
        // LevelViewModel logic updates levels array synchronously on same actor
        guard let updatedLevel = levelViewModel.levels.first(where: { $0.id == levelID }) else {
            XCTFail("Level not found")
            return
        }
        XCTAssertTrue(updatedLevel.isSolved, "Persistence (In-Memory) should be updated")
        
        // 6. Assert Backend (SwiftData) if available
        // Tests run with in-memory container.
        let descriptor = FetchDescriptor<UserLevelProgress>(predicate: #Predicate { $0.levelID == 3000 })
        let results = try? container.mainContext.fetch(descriptor)
        XCTAssertNotNil(results?.first, "Progress should be saved to DB")
        XCTAssertTrue(results?.first?.isSolved ?? false, "DB should record solved status")
        XCTAssertEqual(results?.first?.bestTime, 100.0, "DB should record 'Record Time'")
    }
    func testSelectionToggle() {
        // Select index 0
        gameViewModel.selectCell(0)
        XCTAssertEqual(gameViewModel.selectedCellIndex, 0)
        
        // Tap same index -> Toggle Off (Single Mode Behavior)
        gameViewModel.selectCell(0)
        XCTAssertNil(gameViewModel.selectedCellIndex, "Tapping selected cell should deselect")
        
        // Tap different
        gameViewModel.selectCell(1)
        XCTAssertEqual(gameViewModel.selectedCellIndex, 1)
        gameViewModel.selectCell(2)
        XCTAssertEqual(gameViewModel.selectedCellIndex, 2)
    }
    
    func testHighlightingLogic() {
        // Setup Settings
        let settings = SettingsViewModel()
        gameViewModel.settings = settings
        
        // Setup Board: Index 0='1', Index 1='2', Index 9='0' (Row 1, Col 0), Index 2='1' (Row 0, Col 2)
        // Let's assume board is empty or partial.
        // LevelViewModel loads Level 1 which has clues.
        // Let's use custom level for precision.
        let board = "121000000000000000000000000000000000000000000000000000000000000000000000000000000"
        // Index 0: '1'
        // Index 1: '2'
        // Index 2: '1'
        
        // Use unique ID 4000
        let levelID = 4000
        let customLevel = SudokuLevel(id: levelID, isLocked: false, isSolved: false, board: board, solution: board)
        levelViewModel.levels.append(customLevel)
        let vm = SudokuGameViewModel(levelID: levelID, levelViewModel: levelViewModel)
        vm.settings = settings
        
        // MODE A: Restriction
        settings.highlightMode = .restriction
        vm.selectCell(0) // Select '1' at 0,0
        
        // Check Same Digit
        XCTAssertEqual(vm.getHighlightType(at: 2), .sameValue, "Mode A: Should highlight same digit '1' at index 2")
        
        // Check Box (Index 10 is Row 1, Col 1 -> Box 0)
        XCTAssertEqual(vm.getHighlightType(at: 10), .relating, "Mode A: Should highlight box member")
        
        // Check Row/Col outside box?
        // Index 8 is Row 0, Col 8 (Same Row, Different Box).
        // Current Logic: Only sameValue or Box. Row logic was "Implicitly NOT highlighted".
        // Index 8 is '0', not '1'.
        XCTAssertEqual(vm.getHighlightType(at: 8), .none, "Mode A: Should NOT highlight row outside box/value")
        
        // MODE B: Potential
        settings.highlightMode = .potential
        // Select '1' at 0 (Index 0)
        // Index 8 (Row 0, Col 8) is empty '0'.
        // Is '1' valid at index 8?
        // Row 0 has '1' (at 0). So NO.
        XCTAssertEqual(vm.isValid(1, at: 8, ignoring: 0), false) // Wait, ignoring 0?
        // isValid checks if placing 1 at 8 conflicts with existing board.
        // Existing board HAS '1' at 0.
        // So putting '1' at 8 is invalid.
        // So Highlight should be NONE?
        // Potential Mode: "Highlight all empty cells where that digit could mathematically be placed".
        // Since '1' cannot be placed at 8 (same row), it should NOT be highlighted.
        XCTAssertEqual(vm.getHighlightType(at: 8), .none, "Mode B: '1' invalid in Row 0")
        
        // What about Index 12? (Row 1, Col 3). Box 1.
        // Row 1 empty. Col 3 empty. Box 1 empty.
        // So '1' is valid.
        XCTAssertEqual(vm.getHighlightType(at: 12), .relating, "Mode B: '1' valid at 12")
        
        // Select '2' at 1
        vm.selectCell(1)
        // Index 0 is '1'. Index 12 is '0'.
        // '2' valid at 12?
        XCTAssertEqual(vm.getHighlightType(at: 12), .relating, "Mode B: '2' valid at 12")
    }
    
    func testPotentialModeExclusions() {
        // Setup Settings
        let settings = SettingsViewModel()
        gameViewModel.settings = settings
        settings.highlightMode = .potential
        
        // Setup Board: Index 0 = '5'
        // All others empty for simplicity (or sparse)
        var emptyBoard = Array(String(repeating: "0", count: 81))
        emptyBoard[0] = "5"
        let board = String(emptyBoard)
        
        // Use unique ID 5000
        let levelID = 5000
        let customLevel = SudokuLevel(id: levelID, isLocked: false, isSolved: false, board: board, solution: board)
        levelViewModel.levels.append(customLevel)
        let vm = SudokuGameViewModel(levelID: levelID, levelViewModel: levelViewModel)
        vm.settings = settings
        
        // Select '5' at 0,0
        vm.selectCell(0)
        
        // Assertions:
        
        // 1. Same Row (Index 1..8) -> Should NOT be highlighted
        XCTAssertEqual(vm.getHighlightType(at: 1), .none, "Row 0 neighbor should NOT be highlighted (Conflict with 5)")
        XCTAssertEqual(vm.getHighlightType(at: 8), .none, "Row 0 far neighbor should NOT be highlighted")
        
        // 2. Same Col (Index 9, 18...) -> Should NOT be highlighted
        XCTAssertEqual(vm.getHighlightType(at: 9), .none, "Col 0 neighbor should NOT be highlighted")
        XCTAssertEqual(vm.getHighlightType(at: 72), .none, "Col 0 far neighbor should NOT be highlighted")
        
        // 3. Same Box (Index 10: Row 1, Col 1) -> Should NOT be highlighted
        XCTAssertEqual(vm.getHighlightType(at: 10), .none, "Box 0 neighbor should NOT be highlighted")
        
        // 4. Valid Spot (Row 1, Col 4 -> Index 13)
        // Row 1 (empty), Col 4 (empty), Box 1 (empty). '5' is valid.
        XCTAssertEqual(vm.getHighlightType(at: 13), .relating, "Valid spot (1,4) SHOULD be highlighted")
        
        // 5. Another Valid Spot (Row 2, Col 8 -> Index 26)
        XCTAssertEqual(vm.getHighlightType(at: 26), .relating, "Valid spot (2,8) SHOULD be highlighted")
    }
    
    func testEraseClearsEverything() async {
        let intIndex = 0
        let gameViewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        gameViewModel.selectCell(intIndex)
        
        // 1. Test Erase Value
        gameViewModel.isNoteMode = false
        gameViewModel.enterNumber(2)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(gameViewModel.cells[intIndex].value, 2)
        
        gameViewModel.erase()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(gameViewModel.cells[intIndex].value, 0)
        
        // 2. Test Erase Note
        gameViewModel.isNoteMode = true
        gameViewModel.didTapNumber(3) // Toggle Note 3
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(gameViewModel.cells[intIndex].notes.contains(3))
        
        gameViewModel.erase()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(gameViewModel.cells[intIndex].notes.isEmpty)
        
        // 3. Test Erase Color
        gameViewModel.setCellColor(0) // Red
        XCTAssertNotNil(gameViewModel.cells[intIndex].color)
        
        gameViewModel.erase() // Erase logic for color is sync but wrapped in batch? No, Erase is separate func.
        // But in prev plan erase used addMove async? No, 'erase()' calls loop.
        // Let's check VM erase implementation. It calls addMove. And saveState.
        // 'erase()' calls 'refreshFlag.toggle' (old) or now 'boardID = UUID()'
        // Does erase() use Task?
        // In the ViewModel, verify erase.
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertNil(gameViewModel.cells[intIndex].color)
    }
    
    func testHeaderDisplayLogic() {
        // Test Level 1 (Classic Logic: (1-1)%10 == 0 -> True)
        let vm1 = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        XCTAssertEqual(vm1.levelTitle, "Level 1")
        XCTAssertEqual(vm1.gameTypeInfo.text, "Classic Sudoku")
        XCTAssertEqual(vm1.gameTypeInfo.icon, "square.grid.3x3")
        
        // Test Level 11 (Classic Logic: (11-1)%10 = 0 -> True)
        if !levelViewModel.levels.contains(where: { $0.id == 11 }) {
             let validBoard = String(repeating: "0", count: 81)
             let l11 = SudokuLevel(id: 11, isLocked: false, isSolved: false, board: validBoard, solution: validBoard, ruleType: "classic")
             levelViewModel.levels.append(l11)
        }
        
        let vm11 = SudokuGameViewModel(levelID: 11, levelViewModel: levelViewModel)
        XCTAssertEqual(vm11.levelTitle, "Level 11")
        XCTAssertEqual(vm11.gameTypeInfo.text, "Classic Sudoku")
        
        // Test Level 2 (Variant Logic: (2-1)%10 = 1 -> False)
        // Ensure Level 2 exists with a specific ruleType
        let validBoard = String(repeating: "0", count: 81)
        if let index = levelViewModel.levels.firstIndex(where: { $0.id == 2 }) {
            levelViewModel.levels[index].ruleType = "sandwich"
            if (levelViewModel.levels[index].board?.count ?? 0) != 81 {
                levelViewModel.levels[index].board = validBoard // Ensure length
            }
        } else {
             let l2 = SudokuLevel(id: 2, isLocked: false, isSolved: false, board: validBoard, solution: validBoard, ruleType: "sandwich")
             levelViewModel.levels.append(l2)
        }
        
        let vm2 = SudokuGameViewModel(levelID: 2, levelViewModel: levelViewModel)
        XCTAssertEqual(vm2.levelTitle, "Level 2")
        XCTAssertEqual(vm2.gameTypeInfo.text, "SANDWICH") // Uppercased
        XCTAssertNotEqual(vm2.gameTypeInfo.icon, "square.grid.3x3")
    }
    
    func testUndoRedoPersistence() async {
        let vm = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        
        // Find an empty cell (not a clue)
        guard let stringIndex = vm.currentBoard.firstIndex(of: "0") else {
            XCTFail("No empty cells found in level 1 for testing")
            return
        }
        let index = vm.currentBoard.distance(from: vm.currentBoard.startIndex, to: stringIndex)
        
        vm.selectCell(index)
        
        // Debug History Count
        XCTAssertEqual(vm.levelProgress?.moves?.count ?? 0, 0)
        
        // Move 1: Enter '5'
        vm.enterNumber(5)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.cells[index].value, 5)
        XCTAssertEqual(vm.levelProgress?.moves?.count ?? 0, 1)
        
        // Move 2: Enter '0' (Clear Value)
        vm.enterNumber(0)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.cells[index].value, 0)
        XCTAssertEqual(vm.levelProgress?.moves?.count ?? 0, 2)
        
        // Move 3: Add Note '2'
        vm.toggleNote(2)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(vm.cells[index].notes.contains(2))
        XCTAssertEqual(vm.levelProgress?.moves?.count ?? 0, 3)
        
        // Move 4: Set Color
        vm.setCellColor(1) // Color 1 (Red)
        XCTAssertEqual(vm.cells[index].color, 1)
        XCTAssertEqual(vm.levelProgress?.moves?.count ?? 0, 4)
        
        // Verify History Order?
        // let moves = vm.sortedHistory() // private helper
        
        // Undo Color (Move 4)
        vm.undo()
        XCTAssertNil(vm.cells[index].color, "Undo Color Failed")
        XCTAssertEqual(vm.cells[index].value, 0, "Board should stay 0")
        
        // Undo Note (Move 3)
        vm.undo()
        XCTAssertFalse(vm.cells[index].notes.contains(2), "Undo Note Failed")
        
        // Undo Value 0 -> 5 (Move 2)
        vm.undo()
        XCTAssertEqual(vm.cells[index].value, 5, "Undo Value 0 Failed")
        
        // Redo Value 0 -> 5 (Move 2) => Sets 0
        vm.redo()
        XCTAssertEqual(vm.cells[index].value, 0, "Redo Value 0 Failed")
        
        // Redo Note
        vm.redo()
        XCTAssertTrue(vm.cells[index].notes.contains(2), "Redo Note Failed")
    }
    @MainActor
    func testMultiSelectionBatch() async {
        // 1. Setup
        let vm = SudokuGameViewModel(levelID: 1, levelViewModel: LevelViewModel(modelContext: container.mainContext))
        vm.toggleMultiSelectMode()
        
        // 2. Select 2 cells (0, 1)
        vm.selectCell(0)
        vm.selectCell(1)
        
        XCTAssertEqual(vm.selectedIndices.count, 2)
        XCTAssertTrue(vm.selectedIndices.contains(0))
        XCTAssertTrue(vm.selectedIndices.contains(1))
        
        // 3. Batch Input
        vm.applyNumberBatch(5)
        // Wait for async update/persistence
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // 4. Verify Update
        XCTAssertEqual(vm.cells[0].value, 5)
        XCTAssertEqual(vm.cells[1].value, 5)
        
        // 5. Verify History (Should be capable of Undo)
        // undo() uses batchID to revert all
        vm.undo()
        // Wait for async
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(vm.cells[0].value, 0)
        XCTAssertEqual(vm.cells[1].value, 0)
        
        // 6. Verify Redo
        vm.redo()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.cells[0].value, 5)
        XCTAssertEqual(vm.cells[1].value, 5)
    }
    
    /* Removed old multi tests
    func testMultiSelectionInput() async { ... }
    func testMultiSelectPersistenceAndBatchUndo() async { ... }
    */

    @MainActor
    func testMutualExclusivity() async {
        // 1. Setup
        let vm = SudokuGameViewModel(levelID: 1, levelViewModel: LevelViewModel(modelContext: container.mainContext))
        vm.selectCell(0)
        
        // 2. Enter Number '5' (Value)
        vm.didTapNumber(5)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.cells[0].value, 5)
        XCTAssertTrue(vm.cells[0].notes.isEmpty)
        
        // 3. Switch to Note Mode and Toggle '5' (Note)
        // Should Clear Value 5 -> 0, then Add Note 5
        vm.toggleNoteMode()
        XCTAssertTrue(vm.isNoteMode)
        vm.didTapNumber(5)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertEqual(vm.cells[0].value, 0, "Value MUST be cleared when adding note")
        XCTAssertTrue(vm.cells[0].notes.contains(5), "Note MUST be added")
        
        // 4. Undo
        // Should revert BOTH changes (Clear Value, Add Note) in one go
        vm.undo()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertEqual(vm.cells[0].value, 5, "Undo fail: Should revert to Value 5")
        XCTAssertTrue(vm.cells[0].notes.isEmpty, "Undo fail: Notes should be empty")
        
        // 5. Switch to Value Mode and Enter '6'
        // Should Clear Note 5 (if we redid first)
        vm.redo() // Back to Note 5, Value 0
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        vm.toggleNoteMode() // OFF
        XCTAssertFalse(vm.isNoteMode)
        
        vm.didTapNumber(6)
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertEqual(vm.cells[0].value, 6)
        XCTAssertTrue(vm.cells[0].notes.isEmpty, "Entering Value MUST clear notes")
    }
    @MainActor
    func testToggleToClearValue() async {
        // 1. Setup
        let vm = SudokuGameViewModel(levelID: 1, levelViewModel: LevelViewModel(modelContext: container.mainContext))
        vm.selectCell(0)
        
        // 2. Enter Number '5'
        vm.didTapNumber(5)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.cells[0].value, 5)
        
        // 3. Enter '5' Again (Should Toggle Off)
        vm.didTapNumber(5)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.cells[0].value, 0, "Entering same number should clear it")
        
        // 4. Enter '6' (Should Set)
        vm.didTapNumber(6)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.cells[0].value, 6)
        
        // 5. Undo (Should go 6 -> 0)
        vm.undo()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.cells[0].value, 0)
        
        // 6. Undo (Should go 0 -> 5)
        vm.undo()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.cells[0].value, 5)
    }
    @MainActor
    func testInputRefactor() async {
        // 1. Setup
        let vm = SudokuGameViewModel(levelID: 1, levelViewModel: LevelViewModel(modelContext: container.mainContext))
        vm.selectCell(0)
        
        // 2. Add Note (Setup conflict)
        vm.isNoteMode = true
        vm.didTapNumber(2)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(vm.cells[0].notes.contains(2))
        vm.isNoteMode = false
        
        // 3. Enter Number '5' (Value)
        vm.didTapNumber(5)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // 4. Verification
        // A. Value Updated
        XCTAssertEqual(vm.cells[0].value, 5, "Value should be 5")
        
        // B. Notes Cleared (Explicit Logic)
        XCTAssertTrue(vm.cells[0].notes.isEmpty, "Notes should be cleared")
    }
    @MainActor
    func testBoardIDUpdates() async {
        let vm = SudokuGameViewModel(levelID: 1, levelViewModel: LevelViewModel(modelContext: container.mainContext))
        vm.selectCell(0)
        
        let initialID = vm.boardID
        
        // Action: Enter Number (Wrapped in Task, so we might need to wait or rely on MainActor serialization)
        // Since test is @MainActor and enterNumber uses Task { @MainActor }, the task will be scheduled.
        // We need to wait for it.
        
        vm.enterNumber(5) 
        
        // Yield to let the Task run
        await Task.yield() 
        // A short wait might be needed if yield isn't enough for the dispatched task to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // Assert: ID changed
        XCTAssertNotEqual(vm.boardID, initialID, "Board ID should change on input")
        
        let id2 = vm.boardID
        
        // Action: Erase (Sync in VM currently? Erase wasn't wrapped in Task in my plan, only enterNumber. Let's check VM change.)
        // I only wrapped enterNumber in Task in the plan. Erase is still sync on MainActor?
        // Actually, Erase was NOT wrapped in Task in the replace call above.
        vm.erase()
        
        // Assert: ID changed again
        XCTAssertNotEqual(vm.boardID, id2, "Board ID should change on erase")
    }

    
    func testMinimalHighlightToggle() {
        let settings = SettingsViewModel()
        let vm = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        vm.settings = settings
        
        // 1. Default Mode (Minimal = True)
        // Select Index 0
        vm.selectCell(0)
        
        XCTAssertEqual(vm.getHighlightType(at: 0), .selected, "Selected cell should always be selected")
        // Index 10 (Same Box) should be NONE in minimal mode
        XCTAssertEqual(vm.getHighlightType(at: 10), .none, "Neighbors should be NONE in Minimal Mode")
        
        // 2. Disable Minimal Mode
        settings.isMinimalHighlight = false
        
        // Verify Index 10 is now Relating (Box)
        XCTAssertEqual(vm.getHighlightType(at: 10), .relating, "Neighbors should be RELATING when Minimal Mode is OFF")
        
        // 3. Re-enable Minimal
        settings.isMinimalHighlight = true
        XCTAssertEqual(vm.getHighlightType(at: 10), .none, "Back to None")
    }
    @MainActor
    func testRestartLevelDataPersistence() async {
        // 1. Setup - Use In-Memory vm from test setup
        // Need to simulate "Playing" state
        let vm = SudokuGameViewModel(levelID: 1, levelViewModel: LevelViewModel(modelContext: container.mainContext))
        vm.selectCell(0)
        
        // 2. Add some data (Value, Note, Color)
        vm.enterNumber(5) // Value
        vm.toggleNoteMode()
        vm.didTapNumber(2) // Note
        vm.toggleNoteMode()
        vm.setCellColor(1) // Color
        vm.timeElapsed = 120
        vm.isSolved = true
        
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify Data Exists
        XCTAssertEqual(vm.cells[0].value, 5)
        XCTAssertEqual(vm.levelProgress?.moves?.count ?? 0, 3) 
        
        // 3. Restart Level
        vm.restartLevel()
        
        // Wait for sync (restart is mostly sync but good practice)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // 4. Verification
        
        // A. State Reset
        XCTAssertEqual(vm.timeElapsed, 0, "Time should be 0")
        XCTAssertFalse(vm.isSolved, "isSolved should be false")
        XCTAssertEqual(vm.historyIndex, -1, "History index should be reset")
        
        // B. Board Cleared
        // Index 0 was modified. Should be back to Original.
        // Level 1 Original at 0 is... '4' based on mock in `testSolutionVerification`? 
        // No, Level 1 real data.
        // The mock in `setUp` says logic relies on JSON. 
        // If index 0 is a clue, it won't be cleared.
        // Let's find a non-clue index.
        // Level 1 JSON usually has 0s.
        guard let emptyIndex = vm.currentBoard.firstIndex(of: "0") else { return }
        let intIndex = vm.currentBoard.distance(from: vm.currentBoard.startIndex, to: emptyIndex)
        
        // Let's redo setup on THIS index to be safe
        vm.selectCell(intIndex)
        vm.enterNumber(9)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.cells[intIndex].value, 9)
        
        // Restart Again
        vm.restartLevel()
        
        XCTAssertEqual(vm.cells[intIndex].value, 0, "Non-clue cell should be cleared to 0")
        XCTAssertTrue(vm.cells[intIndex].notes.isEmpty, "Notes should be cleared")
        XCTAssertNil(vm.cells[intIndex].color, "Color should be cleared")
        
        // C. Persistence Cleared
        XCTAssertEqual(vm.levelProgress?.moves?.count ?? 0, 0, "History persistence should be empty")
        XCTAssertNil(vm.levelProgress?.currentUserBoard, "Saved board should be nil")
        
        // D. DB Verify
        // UserLevelProgress should exist but be reset
        let descriptor = FetchDescriptor<UserLevelProgress>(predicate: #Predicate { $0.levelID == 1 })
        let results = try? container.mainContext.fetch(descriptor)
        let savedProgress = results?.first
        XCTAssertNotNil(savedProgress)
        XCTAssertFalse(savedProgress?.isSolved ?? true, "DB isSolved should be false")
        XCTAssertEqual(savedProgress?.timeElapsed, 0, "DB timeElapsed should be 0")
    }
    
    @MainActor
    func testUndoRedo() async {
        // Setup VM
        let vm = SudokuGameViewModel(levelID: 1, levelViewModel: LevelViewModel(modelContext: container.mainContext))
        vm.selectCell(0)
        
        // 1. Initial State
        // Find empty cell
        guard let emptyIndex = vm.currentBoard.firstIndex(of: "0") else { return }
        let intIndex = vm.currentBoard.distance(from: vm.currentBoard.startIndex, to: emptyIndex)
        vm.selectCell(intIndex)
        
        let initialVal = vm.cells[intIndex].value
        XCTAssertEqual(initialVal, 0)
        
        // 2. Perform Action (Enter 5)
        vm.enterNumber(5)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.cells[intIndex].value, 5)
        
        // 3. Undo
        vm.undo()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.cells[intIndex].value, 0, "Value should revert to 0 after undo")
        
        // 4. Redo
        vm.redo()
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(vm.cells[intIndex].value, 5, "Value should restore to 5 after redo")
    }
}
