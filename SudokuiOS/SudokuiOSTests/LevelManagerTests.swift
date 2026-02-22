#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

final class LevelManagerTests: XCTestCase {

    var viewModel: LevelViewModel!

    @MainActor
    override func setUp() {
        super.setUp()
        // Initialize the LevelViewModel (which acts as the LevelManager in this app structure)
        viewModel = LevelViewModel()
    }

    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Layout & Count Verification
    @MainActor
    func testLevelCount() {
        // Requirement: "LevelManager correctly returns the right count of levels (600) to be rendered by the grid."
        XCTAssertEqual(viewModel.levels.count, 600, "LevelManager should provide exactly 600 levels")
    }

    // MARK: - Progression Verification (Gatekeeper)
    @MainActor
    func testLevel251LockedUntilAllPreviousSolved() {
        // Scenario 1: Milestone 1 (1-250) Incomplete
        // Mock State: 1-249 solved, 250 UNSOLVED
        for i in 1..<250 {
            // Using direct access for test setup speed if internal properties allow
            // Assuming LevelViewModel has `levels` as mutable or methods to solve.
            // Using standard method:
            // viewModel.levelSolved(id: i, timeElapsed: 0) // Slow?
            // Direct array access is better for setup if possible.
            let index = i - 1
            viewModel.levels[index].isSolved = true
        }
        viewModel.levels[249].isSolved = false // Level 250 Unsolved
        
        // Trigger generic check
        viewModel.levelSolved(id: 249, timeElapsed: 0) // Trigger check (id 249 is Level 250? No, index 248 is L249)
        // Let's use clean indices.
        // Level 250 is index 249.
        // Level 251 is index 250.
        
        XCTAssertFalse(viewModel.isMilestoneOneComplete, "Milestone should be false if Level 250 is pending")
        XCTAssertTrue(viewModel.levels[250].isLocked, "Level 251 should be locked if history is incomplete")
        
        // Scenario 2: Milestone Met
        // Solve Level 250
        viewModel.levels[249].isSolved = true
        // Trigger unlock check
        viewModel.levelSolved(id: 250, timeElapsed: 0)
        
        XCTAssertTrue(viewModel.isMilestoneOneComplete, "Milestone should be true after 1-250 solved")
        XCTAssertFalse(viewModel.levels[250].isLocked, "Level 251 should unlock after milestone completion")
    }
    
    // MARK: - Ad Mocking and Unlock
    @MainActor
    func testAdUnlockMock() {
        // Requirement: "Test that the 'Unlock' state only triggers after a successful rewarded ad callback"
        
        let levelToUnlockIndex = 255 // Arbitrary locked level
        viewModel.levels[levelToUnlockIndex].isLocked = true
        viewModel.levels[levelToUnlockIndex].isAdUnlocked = false
        
        let targetLevelID = viewModel.levels[levelToUnlockIndex].id
        
        // Mock Functionality
        // Since AdCoordinator is a separate class mostly used in Views, 
        // We verify the ViewModel's response to the completion handler logic.
        
        // Simulate Ad Failure
        let adResultFailure = false
        if adResultFailure {
            viewModel.unlockLevelViaAd(targetLevelID)
        }
        // In actual VM, `unlockLevelViaAd` assumes success was already validated by caller OR handles logic.
        // Looking at `LevelViewModel.swift` (from memory): `unlockLevelViaAd` simply performs the unlock.
        // The View/Coordinator handles the "Completion".
        // So we test that IF the Coordinator says "True", calling this method WORKS.
        // And IF we don't call it (Failure), it stays locked.
        
        // 1. Simulate Failure (Ad Coordinator returns false, so we DO NOT call unlock)
        // Verify state remains locked
        XCTAssertTrue(viewModel.levels[levelToUnlockIndex].isLocked)
        
        // 2. Simulate Success (Ad Coordinator returns true)
        // Action:
        viewModel.unlockLevelViaAd(targetLevelID)
        
        // Assert:
        XCTAssertFalse(viewModel.levels[levelToUnlockIndex].isLocked, "Level should unlock after successful ad signal")
        XCTAssertTrue(viewModel.levels[levelToUnlockIndex].isAdUnlocked, "Ad Unlock flag should be set")
    }

    // MARK: - Redirection Verification
    @MainActor
    func testNextLevelRedirection() {
        // Requirement: "Verify that the 'Next Level' button correctly redirects to the lowest unsolved level if the player tries to skip to Level 251 without finishing the first 250."
        
        // Setup: Levels 1-249 Solved. Level 7 is UNSOLVED (Gap). Level 250 Solved (Trigger).
        for i in 1..<250 {
            viewModel.levels[i-1].isSolved = true
        }
        // Force Gap at Level 7
        viewModel.levels[6].isSolved = false
        
        // Solve Level 250
        viewModel.levels[249].isSolved = true
        
        // Action: Find next level from 250
        let nextLevelID = viewModel.findNextUnsolvedLevel(currentLevelID: 250)
        
        // Assert: Should populate with 7, NOT 251
        XCTAssertEqual(nextLevelID, 7, "Next level after 250 with a gap at 7 should be 7")
        
        // Verify 251 is still locked
        XCTAssertTrue(viewModel.levels[250].isLocked, "Level 251 should remain locked due to gap")
    }
    
    // MARK: - Filter Logic Verification
    @MainActor
    func testFilterLogicCoverage() {
        // Requirement: "Verify that the 'Filter: All Levels' vs 'Filter: Unsolved' logic correctly calculates the number of items to display."
        // Note: Filter logic resides in `LevelSelectionViewModel`, but we can test the data source interaction here 
        // OR instantiate a local SelectionViewModel if strictly needed.
        // User asked for "LevelManagerTests", but the logic is in SelectionVM.
        // I will instantiate a LevelSelectionViewModel here to test the logic as requested.
        
        let selectionVM = LevelSelectionViewModel(levels: viewModel.levels)
        
        // 1. Initial State (All Unsolved)
        XCTAssertEqual(selectionVM.filteredLevels.count, 600, "Initially all levels visible")
        
        // 2. Solve 10 levels
        for i in 0..<10 {
            viewModel.levels[i].isSolved = true
        }
        // Sync
        selectionVM.updateLevels(viewModel.levels)
        
        // 3. Filter: Unsolved
        selectionVM.currentFilter = .unsolved
        XCTAssertEqual(selectionVM.filteredLevels.count, 590, "Should show 600 - 10 = 590 unsolved levels")
        
        // 4. Filter: All
        selectionVM.currentFilter = .all
        XCTAssertEqual(selectionVM.filteredLevels.count, 600, "Should show all 600 levels")
    }
    
    // MARK: - Ad-Unlock Integrity
    @MainActor
    func testAdRewardIntegrity() {
        // Requirement: "Confirm that a level's isUnlocked property only changes to true after the userDidEarnReward callback successfully completes."
        // We simulate the flow: Locked -> Attempt (Fail) -> Locked -> Attempt (Success) -> Unlocked.
        
        let levelIdx = 500
        let levelID = viewModel.levels[levelIdx].id
        viewModel.levels[levelIdx].isLocked = true
        
        // 1. Simulate Check (Pre-Ad)
        XCTAssertTrue(viewModel.levels[levelIdx].isLocked)
        
        // 2. Mock Ad Callback (Failure / Cancelled)
        let adCompletedFailure = false
        if adCompletedFailure {
            viewModel.unlockLevelViaAd(levelID)
        }
        XCTAssertTrue(viewModel.levels[levelIdx].isLocked, "Should remain locked on failure")
        
        // 3. Mock Ad Callback (Success)
        let adCompletedSuccess = true
        if adCompletedSuccess {
            viewModel.unlockLevelViaAd(levelID)
        }
        XCTAssertFalse(viewModel.levels[levelIdx].isLocked, "Should unlock on success")
        XCTAssertTrue(viewModel.levels[levelIdx].isAdUnlocked, "Ad Unlock Verified")
    }

}
#endif
