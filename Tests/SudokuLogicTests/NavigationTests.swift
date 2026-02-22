import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
final class NavigationTests: XCTestCase {
    
    var container: ModelContainer!
    var viewModel: LevelViewModel!
    
    override func setUp() async throws {
        // Setup in-memory stack
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, configurations: config)
        viewModel = LevelViewModel(modelContext: container.mainContext)
    }
    
    override func tearDown() {
        container = nil
        viewModel = nil
    }
    
    func testFirstUnsolvedLevelDefaultsToOne() {
        // Initially no progress
        XCTAssertEqual(viewModel.firstUnsolvedLevelID, 1, "Should start at Level 1")
    }
    
    func testPlayButtonAdvancesToNextLevel() {
        // Simulate solving Level 1
        viewModel.saveProgress(levelId: 1, timeElapsed: 0) // saves isSolved = true
        
        // The property is computed from 'levels' array.
        // saveProgress updates in-memory 'levels' array too.
        
        XCTAssertEqual(viewModel.firstUnsolvedLevelID, 2, "Should proceed to Level 2 after Level 1 is solved")
    }
    
    func testPlayButtonSkipsSolvedLevels() {
        // Simulate solving 1, 2, 3
        // Simulate solving 1, 2, 3
        viewModel.saveProgress(levelId: 1, timeElapsed: 0)
        viewModel.saveProgress(levelId: 2, timeElapsed: 0)
        viewModel.saveProgress(levelId: 3, timeElapsed: 0)
        
        XCTAssertEqual(viewModel.firstUnsolvedLevelID, 4, "Should find first unsolved level (4)")
    }
    
    func testOnAppearRefreshLogic() {
        // Simulate fresh launch where persistence has data but VM is new
        
        // 1. Create data in container
        let ctx = container.mainContext
        let p1 = UserLevelProgress(levelID: 1, isSolved: true)
        ctx.insert(p1)
        try? ctx.save()
        
        // 2. Create NEW ViewModel (simulating App Launch or View Re-creation)
        let newVM = LevelViewModel(modelContext: ctx)
        
        // 3. Verify it loaded the state (init calls loadProgressFromSwiftData)
        XCTAssertTrue(newVM.levels[0].isSolved)
        XCTAssertEqual(newVM.firstUnsolvedLevelID, 2, "New VM should recognize persisted state")
    }
}
