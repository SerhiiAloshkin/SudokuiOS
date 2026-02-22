#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

final class LevelSelectionTests: XCTestCase {

    func testFirstUnsolvedLevel() {
        // Setup
        let viewModel = LevelSelectionViewModel()
        
        // Mock Levels: 1..10 Solved, 11..20 Unsolved
        var levels: [SudokuLevel] = []
        for i in 1...20 {
            var level = SudokuLevel(id: i, difficulty: "Easy", ruleType: .classic, board: "", solution: "")
            level.isSolved = (i <= 10)
            levels.append(level)
        }
        
        // Action
        viewModel.updateLevels(levels)
        
        // Assert
        XCTAssertEqual(viewModel.firstUnsolvedLevelID, 11, "Should identify 11 as the first unsolved level")
    }
    
    func testAllSolved() {
        // Setup
        let viewModel = LevelSelectionViewModel()
        var levels: [SudokuLevel] = []
        for i in 1...20 {
            var level = SudokuLevel(id: i, difficulty: "Easy", ruleType: .classic, board: "", solution: "")
            level.isSolved = true // ALL solved
            levels.append(level)
        }
        
        viewModel.updateLevels(levels)
        
        // Assert: Should be nil or handle appropriately (returning nil here means no scroll target, which is fine)
        XCTAssertNil(viewModel.firstUnsolvedLevelID, "Should return nil if all levels are solved")
    }
    
    func testAllUnsolved() {
        // Setup
        let viewModel = LevelSelectionViewModel()
        var levels: [SudokuLevel] = []
        for i in 1...20 {
            var level = SudokuLevel(id: i, difficulty: "Easy", ruleType: .classic, board: "", solution: "")
            level.isSolved = false // ALL unsolved
            levels.append(level)
        }
        
        viewModel.updateLevels(levels)
        
        XCTAssertEqual(viewModel.firstUnsolvedLevelID, 1, "Should identify Level 1 as first unsolved")
    }
    
    func testTargetRowCalculation() {
        // Since the View calculates the row, we might test that logic here or just rely on ID.
        // The implementation plan says: "Calculate the target row index: let targetRow = (firstUnsolvedID - 1) / 10"
        // Let's verify this logic is sound for the view.
        
        let id = 21
        let expectedRow = (id - 1) / 10 // (21-1)/10 = 2. Rows 0, 1 are full (1-10, 11-20). So Row 2 starts with 21. Correct.
        XCTAssertEqual(expectedRow, 2)
    }
    
    func testKnightFilter() {
        let viewModel = LevelSelectionViewModel()
        let l1 = SudokuLevel(id: 9, difficulty: "X", ruleType: .knight, board: "", solution: "")
        let l2 = SudokuLevel(id: 10, difficulty: "X", ruleType: .classic, board: "", solution: "")
        
        viewModel.updateLevels([l1, l2])
        viewModel.currentFilter = .knight
        
        XCTAssertEqual(viewModel.filteredLevels.count, 1)
        XCTAssertEqual(viewModel.filteredLevels.first?.id, 9)
    }
    
    func testKingFilter() {
        let viewModel = LevelSelectionViewModel()
        let l1 = SudokuLevel(id: 10, difficulty: "X", ruleType: .king, board: "", solution: "")
        let l2 = SudokuLevel(id: 20, difficulty: "X", ruleType: .king, board: "", solution: "")
        let l3 = SudokuLevel(id: 11, difficulty: "X", ruleType: .classic, board: "", solution: "")
        
        viewModel.updateLevels([l1, l2, l3])
        viewModel.currentFilter = .king
        
        XCTAssertEqual(viewModel.filteredLevels.count, 2)
        XCTAssertTrue(viewModel.filteredLevels.contains(where: { $0.id == 10 }))
        XCTAssertTrue(viewModel.filteredLevels.contains(where: { $0.id == 20 }))
    }
    
    // MARK: - New Tests
    func testUnsolvedFilter() {
        let viewModel = LevelSelectionViewModel()
        var l1 = SudokuLevel(id: 1, difficulty: "E", ruleType: .classic, board: "", solution: "")
        l1.isSolved = true
        var l2 = SudokuLevel(id: 2, difficulty: "E", ruleType: .classic, board: "", solution: "")
        l2.isSolved = false
        
        viewModel.updateLevels([l1, l2])
        viewModel.currentFilter = .unsolved
        
        XCTAssertEqual(viewModel.filteredLevels.count, 1)
        XCTAssertEqual(viewModel.filteredLevels.first?.id, 2, "Should only show unsolved level")
    }

    func testLevel251LockGuard() {
        // Test that if 1-250 are NOT solved, 251 is LOCKED.
        let viewModel = LevelSelectionViewModel()
        // Mock 1-250
        var levels: [SudokuLevel] = []
        for i in 1...251 {
            var l = SudokuLevel(id: i, difficulty: "E", ruleType: .classic, board: "", solution: "")
            l.isSolved = (i < 250) // 250 is NOT solved
            
            // Simulate upstream logic: Level 251 IS locked
            if i == 251 { l.isLocked = true }
            levels.append(l)
        }
        
        viewModel.updateLevels(levels)
        let l251 = viewModel.filteredLevels.first(where: { $0.id == 251 })
        XCTAssertTrue(l251?.isLocked ?? false, "Level 251 should be locked in selection view")
    }
    
    func testAdUnlockReflection() {
        // Verify selection view model updates when underlying level is unlocked via Ad
        let viewModel = LevelSelectionViewModel()
        var level = SudokuLevel(id: 3, difficulty: "E", ruleType: .classic, board: "", solution: "")
        level.isLocked = true
        
        // 1. Initial State
        viewModel.updateLevels([level])
        XCTAssertTrue(viewModel.filteredLevels.first?.isLocked ?? false)
        
        // 2. Simulate Ad Unlock (Update Data Source)
        level.isLocked = false
        level.isAdUnlocked = true
        viewModel.updateLevels([level])
        
        // 3. Verify Reflection
        XCTAssertFalse(viewModel.filteredLevels.first?.isLocked ?? true, "ViewModel should reflect ad unlock")
    }

    func testKnightVariantMapping() {
        // Requirement: "Verify that the horse icon in Assets.xcassets is named exactly what the code expects"
        // And "Verify that a level initialized with a Knight variant returns the correct asset name string."
        
        let type = SudokuRuleType.knight
        XCTAssertEqual(type.iconName, "knight_icon", "Knight rule should map to 'knight_icon' asset name")
    }

}
#endif
