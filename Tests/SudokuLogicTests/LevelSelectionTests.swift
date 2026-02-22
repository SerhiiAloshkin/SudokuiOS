import XCTest
@testable import SudokuiOS

class LevelSelectionTests: XCTestCase {
    
    var viewModel: LevelSelectionViewModel!
    
    override func setUp() {
        super.setUp()
        // Mock Data
        let levels = [
            SudokuLevel(id: 1, isLocked: false, isSolved: true, ruleType: "classic"),
            SudokuLevel(id: 2, isLocked: false, isSolved: false, ruleType: "classic"),
            SudokuLevel(id: 3, isLocked: false, isSolved: true, ruleType: "non-consecutive"),
            SudokuLevel(id: 4, isLocked: true, isSolved: false, ruleType: "sandwich"),
            SudokuLevel(id: 5, isLocked: true, isSolved: false, ruleType: "thermo")
        ]
        viewModel = LevelSelectionViewModel(levels: levels)
    }
    
    func testFilterCycle() {
        // Initial state
        XCTAssertEqual(viewModel.currentFilter, .all)
        
        // Cycle 1: Solved
        viewModel.cycleFilter()
        XCTAssertEqual(viewModel.currentFilter, .solved)
        
        // Cycle 2: Unsolved
        viewModel.cycleFilter()
        XCTAssertEqual(viewModel.currentFilter, .unsolved)
        
        // Cycle 3: Classic
        viewModel.cycleFilter()
        XCTAssertEqual(viewModel.currentFilter, .classic)
        
        // Cycle 4: Non-Consecutive
        viewModel.cycleFilter()
        XCTAssertEqual(viewModel.currentFilter, .nonConsecutive)
        
        // Cycle 5: Sandwich
        viewModel.cycleFilter()
        XCTAssertEqual(viewModel.currentFilter, .sandwich)
        
        // Cycle 6: Thermo
        viewModel.cycleFilter()
        XCTAssertEqual(viewModel.currentFilter, .thermo)
        
        // Cycle 7: Back to All
        viewModel.cycleFilter()
        XCTAssertEqual(viewModel.currentFilter, .all)
    }
    
    func testFilterLogic_Solved() {
        viewModel.currentFilter = .solved
        let result = viewModel.filteredLevels
        XCTAssertEqual(result.count, 2) // ID 1, 3
        XCTAssertTrue(result.allSatisfy { $0.isSolved })
    }
    
    func testFilterLogic_Unsolved() {
        viewModel.currentFilter = .unsolved
        let result = viewModel.filteredLevels
        XCTAssertEqual(result.count, 3) // ID 2, 4, 5
        XCTAssertTrue(result.allSatisfy { !$0.isSolved })
    }
    
    func testFilterLogic_RuleType() {
        viewModel.currentFilter = .classic
        XCTAssertEqual(viewModel.filteredLevels.count, 2) // ID 1, 2
        
        viewModel.currentFilter = .nonConsecutive
        XCTAssertEqual(viewModel.filteredLevels.count, 1) // ID 3
        
        viewModel.currentFilter = .sandwich
        XCTAssertEqual(viewModel.filteredLevels.count, 1) // ID 4
        
        viewModel.currentFilter = .thermo
        XCTAssertEqual(viewModel.filteredLevels.count, 1) // ID 5
    }
    
    func testEmptyState() {
        // Test filtering that yields no results
        let emptyVM = LevelSelectionViewModel(levels: [])
        emptyVM.currentFilter = .classic
        XCTAssertTrue(emptyVM.filteredLevels.isEmpty)
    }
}
