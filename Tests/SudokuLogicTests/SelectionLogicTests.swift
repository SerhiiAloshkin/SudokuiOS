import XCTest
@testable import SudokuiOS

class SelectionLogicTests: XCTestCase {
    
    var viewModel: SudokuGameViewModel!
    
    @MainActor
    override func setUp() async throws {
        // Mock Dependencies
        let container = try! ModelContainer(for: UserLevelProgress.self, MoveHistory.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let levelVM = LevelViewModel(modelContext: container.mainContext)
        viewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelVM)
    }

    @MainActor
    func testModeOFFReset() {
        // Mode OFF Reset
        // 1. Click outside selection -> Reset to new target
        viewModel.selectedIndices = [5, 6]
        viewModel.isMultiSelectMode = false
        
        var target = 10
        viewModel.gestureStart(at: target)
        viewModel.dragToggle(target)
        XCTAssertEqual(viewModel.selectedIndices, [10])
        
        // 2. Click INSIDE selection (New Behavior: Reset to target if multiple were selected)
        viewModel.selectedIndices = [5, 6, 7]
        target = 6
        viewModel.gestureStart(at: target)
        viewModel.dragToggle(target)
        
        XCTAssertEqual(viewModel.selectedIndices, [6])
    }
    
    @MainActor
    func testModeONPersistence() {
        // Mode ON Persistence: Verify that if selectedIndices contains [5, 6] and a new tap occurs on [10], the Set becomes [5, 6, 10].
        viewModel.selectedIndices = [5, 6]
        viewModel.isMultiSelectMode = true
        
        let target = 10
        viewModel.gestureStart(at: target)
        viewModel.dragToggle(target)
        
        XCTAssertTrue(viewModel.selectedIndices.contains(5))
        XCTAssertTrue(viewModel.selectedIndices.contains(6))
        XCTAssertTrue(viewModel.selectedIndices.contains(10))
        XCTAssertEqual(viewModel.selectedIndices.count, 3)
    }
    
    @MainActor
    func testDragToggleModeON() {
         // Drag Toggle (Mode ON): Verify dragging over existing selection removes them.
         viewModel.selectedIndices = [5, 6]
         viewModel.isMultiSelectMode = true
         
         // Drag over 5
         viewModel.gestureStart(at: 5) // Start at 5
         viewModel.dragToggle(5)
         
         XCTAssertFalse(viewModel.selectedIndices.contains(5))
         XCTAssertTrue(viewModel.selectedIndices.contains(6))
         
         // Continue drag to 6
         // (No gestureStart, just toggle)
         viewModel.dragToggle(6)
         XCTAssertFalse(viewModel.selectedIndices.contains(6))
         
         XCTAssertTrue(viewModel.selectedIndices.isEmpty)
    }
    
    @MainActor
    func testDragToggleModeOFF_Additive() {
        // Drag in Single Mode should still be additive for the duration of the gesture (Temporary Multi)
        viewModel.selectedIndices = []
        viewModel.isMultiSelectMode = false
        
        // Drag 0
        viewModel.gestureStart(at: 0)
        viewModel.dragToggle(0)
        
        // Drag 1
        // No gestureStart
        viewModel.dragToggle(1)
        
        XCTAssertTrue(viewModel.selectedIndices.contains(0))
        XCTAssertTrue(viewModel.selectedIndices.contains(1))
    }
}
