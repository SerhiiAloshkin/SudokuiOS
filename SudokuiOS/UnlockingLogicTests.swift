#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

class UnlockingLogicTests: XCTestCase {
    
    var viewModel: LevelViewModel!
    
    @MainActor
    override func setUp() {
        super.setUp()
        // Initialize with in-memory ModelContext if possible, or nil for pure logic tests if decoupled.
        // LevelViewModel logic relies on `levels` array mostly. Persistence is secondary for this logic test.
        viewModel = LevelViewModel(modelContext: nil) 
        
        // Reset all to locked/unsolved for testing
        for i in 0..<viewModel.levels.count {
            viewModel.levels[i].isSolved = false
            viewModel.levels[i].isLocked = true
            viewModel.levels[i].isAdUnlocked = false
        }
        
        // Ensure Level 1 is unlocked initially (logic should handle this on refresh)
        // We need to trigger distinct logic check if it's private.
        // Actually refreshLocks is private. We can infer state by checking levels[0].isLocked.
        // We might need to mock levelSolved() to trigger updates.
    }
    
    @MainActor
    func testInitialState() {
        // Force refresh
        viewModel.levelSolved(id: -1, timeElapsed: 0) // Dummy call to trigger refresh? 
        // Or make refreshLocks internal/testable? 
        // Ideally we test public API.
        
        // Level 1 should be unlocked
        XCTAssertFalse(viewModel.levels[0].isLocked, "Level 1 must be unlocked by default")
        // Level 2 should be locked
        XCTAssertTrue(viewModel.levels[1].isLocked, "Level 2 must be locked")
    }
    
    @MainActor
    func testSequentialUnlock() {
        // Solve Level 1
        viewModel.levelSolved(id: 1, timeElapsed: 10)
        
        XCTAssertTrue(viewModel.levels[0].isSolved)
        XCTAssertFalse(viewModel.levels[1].isLocked, "Level 2 should unlock after Level 1 is solved")
        XCTAssertTrue(viewModel.levels[2].isLocked, "Level 3 should remain locked")
    }
    
    @MainActor
    func testGapHandling() {
        // Levels 1, 2 Solved
        viewModel.levelSolved(id: 1, timeElapsed: 10)
        viewModel.levelSolved(id: 2, timeElapsed: 10)
        
        // Level 3 Unlocked naturally.
        XCTAssertFalse(viewModel.levels[2].isLocked)
        
        // User watches Ad for Level 5 (Skip 3 and 4)
        viewModel.unlockLevelViaAd(5)
        
        XCTAssertFalse(viewModel.levels[4].isLocked, "Level 5 should be unlocked via Ad")
        XCTAssertTrue(viewModel.levels[3].isLocked, "Level 4 should remain locked (Gap)")
        
        // Solve Level 5
        viewModel.levelSolved(id: 5, timeElapsed: 10)
        
        // Level 3 should STILL be the "Natural" next one.
        // Level 4 is Locked.
        // Level 6 is Locked (Level 5 solved, but 4 is gap).
        // Let's check logic: naturalUnlockID is the FIRST unsolved level (Level 3 / id 3).
        // Level 6 (id 6) -> isSolved=False, isAdUnlocked=False.
        // id != naturalUnlockID (3).
        // So Level 6 should be Locked.
        
        XCTAssertTrue(viewModel.levels[5].isLocked, "Level 6 should be locked because Level 4 is a gap")
        XCTAssertFalse(viewModel.levels[2].isLocked, "Level 3 should remain unlocked as the natural next step")
    }
    
    @MainActor
    func testBarrierLogic() {
        // Mock: Levels 1-250 Solved
        // This is slow loop, but necessary
        for i in 1...250 {
            viewModel.levelSolved(id: i, timeElapsed: 0)
        }
        
        XCTAssertFalse(viewModel.levels[250].isLocked, "Level 251 should be unlocked now")
        XCTAssertTrue(viewModel.levels[251].isLocked, "Level 252 should be locked")
    }
    
    @MainActor
    func testRemoveAdsUnlock() {
        // Simulate Purchase
        UserDefaults.standard.set(true, forKey: "isAdFree")
        
        // Trigger Refresh
        viewModel.levelSolved(id: -1, timeElapsed: 0)
        
        XCTAssertFalse(viewModel.levels[249].isLocked, "Level 250 should be unlocked with Remove Ads")
        XCTAssertTrue(viewModel.levels[300].isLocked, "Level 301 should remain locked (Barrier)")
        
        // Clean up
        UserDefaults.standard.set(false, forKey: "isAdFree")
    }
    
    @MainActor
    func testLevel250GateLogic() {
        // Simulate: Levels 1-249 Solved
        // We will just directly access `levels` to set state for speed, 
        // relying on LevelViewModel's internal "refreshLocks" to pick it up?
        // Actually, LevelViewModel usually recalculates on `levelSolved`. 
        // We can manually loop solve.
        
        // 1. Solve 1-249
        // This is efficient enough for a unit test map
        for i in 1..<250 {
            let idx = i - 1
            viewModel.levels[idx].isSolved = true
        }
        
        // 2. Refresh
        viewModel.levelSolved(id: 249, timeElapsed: 0)
        
        // 3. Status Check: 250 (Index 249) should be UNLOCKED (Natural)
        XCTAssertFalse(viewModel.levels[249].isLocked, "Level 250 should be unlocked naturally")
        
        // 4. Status Check: 251 (Index 250) should be LOCKED (Gate)
        // Even if we solve 250 via Ad or naturally, if we have gaps, it's irrelevant here since we satisfy all.
        // But let's verify the GATE itself first.
        XCTAssertTrue(viewModel.levels[250].isLocked, "Level 251 must be locked initially")
        
        // 5. Solve 250
        viewModel.levelSolved(id: 250, timeElapsed: 0)
        
        // 6. NOW Level 251 should be UNLOCKED because 1-250 are ALL solved
        XCTAssertFalse(viewModel.levels[250].isLocked, "Level 251 should unlock after 1-250 are solved")
        
        // GAP SCENARIO
        // Reset
        setUp() 
        
        // Leave Level 5 Unsolved (Gap)
        for i in 1...250 {
            if i == 5 { continue }
            let idx = i - 1
            viewModel.levels[idx].isSolved = true
        }
        
        // Trigger check
        viewModel.levelSolved(id: 250, timeElapsed: 0)
        
        // Level 251 should be LOCKED because Level 5 is missing
        XCTAssertTrue(viewModel.levels[250].isLocked, "Level 251 should REMAIN locked due to gap at Level 5")
        
        // Check computed property logic helper
        // We can't access `isMilestoneOneComplete` easily if it relies on internal state update? 
        // It is a computed property on ViewModel.
        XCTAssertFalse(viewModel.isMilestoneOneComplete, "Milestone should be incomplete")
    }
    
    @MainActor
    func testAdUnlockLogic() {
        // Setup: Level 3 is locked
        // 1 & 2 are solved (implicitly for this test scenario to make 3 natural?)
        // Or just force lock 3.
        viewModel.levels[2].isLocked = true
        viewModel.levels[2].isAdUnlocked = false
        
        // Action: Unlock via Ad
        viewModel.unlockLevelViaAd(3)
        
        // Verify
        XCTAssertTrue(viewModel.levels[2].isAdUnlocked, "Level 3 should be marked as Ad Unlocked")
        XCTAssertFalse(viewModel.levels[2].isLocked, "Level 3 should be unlocked")
        
        // Verify Persistence (Mock check)
        // Since we don't have a real Context, we check the flag on the model object.
        // In a real app, we'd check if `saveState` was called.
    }
}
#endif
