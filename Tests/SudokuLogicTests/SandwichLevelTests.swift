#if canImport(XCTest)
import XCTest
@testable import SudokuLogic

class SandwichLevelTests: XCTestCase {
    
    var viewModel: LevelViewModel!
    
    override func setUp() {
        super.setUp()
        // Initialize VM, which triggers JSON load
        viewModel = LevelViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testLevel3LoadsBoard() {
        // Test 1: Verify that Level 3 loads a non-empty array of cells from the "board" property.
        guard let level3 = viewModel.levels.first(where: { $0.id == 3 }) else {
            XCTFail("Level 3 not found in loaded levels")
            return
        }
        
        XCTAssertNotNil(level3.board, "Level 3 board string should not be nil")
        XCTAssertFalse(level3.board?.isEmpty ?? true, "Level 3 board string should not be empty")
        XCTAssertEqual(level3.board?.count, 81, "Level 3 board string should contain 81 characters")
        
        // Initial "board" string should contain some non-zero digits (sandwich givens)
        let hasGivens = level3.board?.contains(where: { $0 != "0" }) ?? false
        XCTAssertTrue(hasGivens, "Level 3 should have initial givens (numbers on the board)")
    }
    
    func testLevel3RowSumParsing() {
        // Test 2: Verify that the 1st row sum for Level 3 is correctly parsed as 23.
        guard let level3 = viewModel.levels.first(where: { $0.id == 3 }) else {
            XCTFail("Level 3 not found")
            return
        }
        
        XCTAssertNotNil(level3.rowClues, "Row clues should be present for Level 3")
        XCTAssertEqual(level3.rowClues?.count, 9, "Should have 9 row clues")
        
        // JSON has [23, 0, 8, ... ]
        if let firstSum = level3.rowClues?.first {
            XCTAssertEqual(firstSum, 23, "First row sum should be 23")
        } else {
            XCTFail("Row clues array is empty")
        }
    }
    
    func testLevel3SolutionLoading() {
        // Test 3: Confirm that the board's solution string is also correctly loaded for mistake-checking.
        guard let level3 = viewModel.levels.first(where: { $0.id == 3 }) else {
            XCTFail("Level 3 not found")
            return
        }
        
        XCTAssertNotNil(level3.solution, "Solution string should be loaded")
        XCTAssertEqual(level3.solution?.count, 81, "Solution should have 81 characters")
        
        // Basic sanity check: Solution should not be all zeros
        let hasContent = level3.solution?.contains(where: { $0 != "0" }) ?? false
        XCTAssertTrue(hasContent, "Solution cannot be empty/zeros")
    }
    
    func testGutterClueInheritance() {
        // Verify ViewModel inherits clues from Level
        // This simulates what GameViewModel does (roughly)
        
        guard let level3 = viewModel.levels.first(where: { $0.id == 3 }) else { return }
        
        let gameVM = SudokuGameViewModel(levelID: 3, levelViewModel: viewModel)
        // Wait for init? Init is synchronous.
        
        XCTAssertNotNil(gameVM.rowClues, "GameViewModel should have row clues")
        XCTAssertEqual(gameVM.rowClues?.first, 23, "GameViewModel should inherit 23 as first row clue")
        XCTAssertNotNil(gameVM.colClues, "GameViewModel should have col clues")
    }
}
#endif
