#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

class LevelViewModelTests: XCTestCase {
    
    var viewModel: LevelViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = LevelViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testInitialState() {
        // Verify we have 600 levels
        XCTAssertEqual(viewModel.levels.count, 600, "Should satisfy requirement of 600 levels")
        
        // Verify Level 1 is unlocked
        if let firstLevel = viewModel.levels.first(where: { $0.id == 1 }) {
             XCTAssertFalse(firstLevel.isLocked, "Level 1 should be unlocked by default")
        } else {
            XCTFail("Level 1 not found")
        }
        
        // Verify Level 2 is locked
        if let secondLevel = viewModel.levels.first(where: { $0.id == 2 }) {
             XCTAssertTrue(secondLevel.isLocked, "Level 2 should be locked by default")
        } else {
            XCTFail("Level 2 not found")
        }
    }
}
#endif

