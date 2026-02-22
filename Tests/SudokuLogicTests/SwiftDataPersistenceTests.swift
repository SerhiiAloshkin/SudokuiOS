import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
final class SwiftDataPersistenceTests: XCTestCase {
    
    var container: ModelContainer!
    var viewModel: LevelViewModel!
    
    override func setUp() async throws {
        // Create an in-memory container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, configurations: config)
        
        // Initialize ViewModel with the context
        viewModel = LevelViewModel(modelContext: container.mainContext)
    }
    
    override func tearDown() {
        container = nil
        viewModel = nil
    }
    
    // MARK: - Testing
    
    func testInitializationFetchesEmptyState() {
        // Initially, no progress should be in SwiftData, so 1-10 unlocked, others locked
        XCTAssertFalse(viewModel.levels[0].isSolved)
        XCTAssertNil(viewModel.levels[0].userProgress)
        XCTAssertTrue(viewModel.levels[10].isLocked) // Level 11
    }
    
    func testSavingProgressPersists() async throws {
        // Solve Level 1
        viewModel.levelSolved(id: 1, timeElapsed: 0)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Verify in-memory
        XCTAssertTrue(viewModel.levels[0].isSolved)
        
        // Create NEW ViewModel attached to SAME container (simulate app relaunch)
        let newViewModel = LevelViewModel(modelContext: container.mainContext)
        
        // Verify Persistence
        XCTAssertTrue(newViewModel.levels[0].isSolved, "Level 1 solved status should persist in SwiftData")
    }
    
    func testDataIsolation() throws {
        // Modify Level 1
        viewModel.saveLevelProgress(levelId: 1, currentBoard: "12345...")
        
        // Verify Level 2 is clean
        XCTAssertNil(viewModel.levels[1].userProgress)
        
        // Fetch direct from context to be sure
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserLevelProgress>()
        let allProgress = try context.fetch(descriptor)
        
        XCTAssertEqual(allProgress.count, 1, "Should only have one progress record")
        XCTAssertEqual(allProgress.first?.levelID, 1)
        XCTAssertEqual(allProgress.first?.currentUserBoard, "12345...")
    }
    
    func testBatchUnlockViaSwiftData() {
        // Solve 1-10
        for i in 1...10 {
            viewModel.levelSolved(id: i, timeElapsed: 0)
        }
        
        // Verify 11 unlocked
        XCTAssertFalse(viewModel.levels[10].isLocked)
        
        // Re-init
        let newViewModel = LevelViewModel(modelContext: container.mainContext)
        
        // Verify 11 Unlocked in new session
        XCTAssertFalse(newViewModel.levels[10].isLocked, "Level 11 should be unlocked after loading solved batch from SwiftData")
    }
    func testPersistenceSurvivability() async {
        let levelID = 1 // Use a Milestone level (valid board)
        let gameVM = SudokuGameViewModel(levelID: levelID, levelViewModel: viewModel)
        
        // 1. Find Empty Cell (Safe for Board mod)
        // If loaded level 1 has no empty cells (unlikely), fallback.
        guard let emptyIndex = gameVM.currentBoard.firstIndex(of: "0") else {
            XCTFail("Level 5 should have empty cells")
            return
        }
        let intIndex = gameVM.currentBoard.distance(from: gameVM.currentBoard.startIndex, to: emptyIndex)
        
        // 2. Modify Board (Permanent)
        gameVM.selectCell(intIndex)
        gameVM.didTapNumber(9)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // 3. Add Note (Find an empty cell that is NOT the one we just filled)
        // Since we filled 'intIndex', let's search currentBoard again (it's updated).
        guard let noteIndexFinder = gameVM.currentBoard.firstIndex(of: "0") else {
            XCTFail("Level 5 should have >1 empty cells")
            return
        }
        let noteIndex = gameVM.currentBoard.distance(from: gameVM.currentBoard.startIndex, to: noteIndexFinder)
        
        gameVM.selectCell(noteIndex)
        gameVM.isNoteMode = true
        gameVM.didTapNumber(4)
        try? await Task.sleep(nanoseconds: 100_000_000)
        gameVM.isNoteMode = false
        
        // 4. Set Color (Same index as Note is fine)
        gameVM.setCellColor(3)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // 5. Re-init (Simulate App Restart)
        // Note: In-Memory container persists object graph as long as 'container' is alive.
        // We create new VMs attached to same container.
        let newLevelVM = LevelViewModel(modelContext: container.mainContext)
        let newGameVM = SudokuGameViewModel(levelID: levelID, levelViewModel: newLevelVM)
        
        // 6. Assert
        let charIndex = newGameVM.currentBoard.index(newGameVM.currentBoard.startIndex, offsetBy: intIndex)
        XCTAssertEqual(String(newGameVM.currentBoard[charIndex]), "9", "Board progress should persist")
        
        XCTAssertTrue(newGameVM.notes[noteIndex]?.contains(4) ?? false, "Notes should persist")
        XCTAssertEqual(newGameVM.cellColors[noteIndex], 3, "Colors should persist")
    }
    func testAtomicSurvivability() throws {
        // 1. Setup Real Persistence (Not In-Memory)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("sqlite")
        let schema = Schema([UserLevelProgress.self])
        let config = ModelConfiguration(url: tempURL)
        
        // Phase 1: Write
        var container: ModelContainer? = try ModelContainer(for: schema, configurations: config)
        var levelVM: LevelViewModel? = LevelViewModel(modelContext: container!.mainContext)
        
        // Act: Save a level
        // Since we updated saveLevelProgress to be 'atomic' (saving to context immediately),
        // we just call the VM method. Since VM is @MainActor, we await if in async context,
        // but this test class is @MainActor, so direct call is fine.
        levelVM?.saveLevelProgress(levelId: 99, currentBoard: "TEST_BOARD_DATA")
        
        // Explicitly nil out to simulate app death
        levelVM = nil
        container = nil
        
        // Phase 2: Read
        let newContainer = try ModelContainer(for: schema, configurations: config)
        let context = newContainer.mainContext
        let descriptor = FetchDescriptor<UserLevelProgress>(predicate: #Predicate { $0.levelID == 99 })
        
        let results = try context.fetch(descriptor)
        
        // Assert
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.currentUserBoard, "TEST_BOARD_DATA")
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    func testNotesPersistence() async throws {
        // 1. Setup Persistence
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("sqlite")
        let schema = Schema([UserLevelProgress.self])
        let config = ModelConfiguration(url: tempURL)
        
        // Phase 1: Create Notes
        var container: ModelContainer? = try ModelContainer(for: schema, configurations: config)
        var levelVM: LevelViewModel? = LevelViewModel(modelContext: container!.mainContext)
        var gameVM: SudokuGameViewModel? = SudokuGameViewModel(levelID: 1, levelViewModel: levelVM!)
        
        // Act: Enter notes 1, 3, 5 in a safe empty cell
        // Level 1 likely has clues. We must find an empty spot.
        guard let emptyIndex = gameVM?.currentBoard.firstIndex(of: "0") else {
             XCTFail("No empty cells in Level 1")
             return
        }
        let targetIndex = gameVM!.currentBoard.distance(from: gameVM!.currentBoard.startIndex, to: emptyIndex)
        
        gameVM?.selectCell(targetIndex)
        gameVM?.isNoteMode = true
        gameVM?.didTapNumber(1)
        gameVM?.didTapNumber(3)
        gameVM?.didTapNumber(5)
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Debug Phase 1: Verify in-memory state
        let notes = gameVM?.cells[targetIndex].notes ?? []
        guard !notes.isEmpty else { XCTFail("Notes not set in memory"); return }
        XCTAssertTrue(notes.contains(1))
        XCTAssertTrue(notes.contains(3))
        XCTAssertTrue(notes.contains(5))
        
        // Debug Phase 1: Verify Context state direct check
        try container?.mainContext.save() // Explicit save to ensure flushed
        let checkDesc = FetchDescriptor<UserLevelProgress>(predicate: #Predicate { $0.levelID == 1 })
        let checkResults = try container?.mainContext.fetch(checkDesc)
        XCTAssertEqual(checkResults?.count, 1, "Should have 1 progress record")
        XCTAssertNotNil(checkResults?.first?.notesData, "notesData should not be nil in DB")
        
        // Teardown
        gameVM = nil
        levelVM = nil
        container = nil
        
        // Phase 2: Read
        let newContainer = try ModelContainer(for: schema, configurations: config)
        let newLevelVM = LevelViewModel(modelContext: newContainer.mainContext)
        let newGameVM = SudokuGameViewModel(levelID: 1, levelViewModel: newLevelVM)
        
        // Assert
        let savedNotes = newGameVM.cells[targetIndex].notes
        XCTAssertNotNil(savedNotes)
        XCTAssertTrue(savedNotes.contains(1))
        XCTAssertTrue(savedNotes.contains(3))
        XCTAssertTrue(savedNotes.contains(5))
        XCTAssertEqual(savedNotes.count, 3)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    func testTimerPersistence() {
        // 1. Setup VM and Timer
        let levelID = 1
        let gameVM = SudokuGameViewModel(levelID: levelID, levelViewModel: viewModel)
        
        // 2. Simulate User Progress (Time)
        let targetTime = 90 // 1:30
        gameVM.startTimer() // Ensure timer logic is active
        gameVM.timeElapsed = targetTime
        
        // 3. Stop and Save
        gameVM.stopTimer()
        
        // 4. Re-initialize (Simulate App Restart)
        // Since we are using the same 'viewModel' (which holds the in-memory 'levels' and 'swiftData' context),
        // we can just create a new GameVM.
        // NOTE: In real app, `viewModel` would be re-created from SwiftData.
        // Here, `viewModel` is shared in test setUp unless we create a fresh one.
        // But `SudokuGameViewModel.init` calls `loadLevelData()`.
        
        let newGameVM = SudokuGameViewModel(levelID: levelID, levelViewModel: viewModel)
        
        // 5. Verify Time
        XCTAssertEqual(newGameVM.timeElapsed, targetTime, "Timer should resume at 90 seconds")
        XCTAssertEqual(newGameVM.formattedTime, "00:01:30", "Formatted time should match 00:01:30")
    }
}

