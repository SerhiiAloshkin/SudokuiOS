import XCTest
import SwiftData
@testable import SudokuLogic

@MainActor
class PruningTests: XCTestCase {
    
    var viewModel: SudokuGameViewModel!
    var levelViewModel: LevelViewModel!
    var container: ModelContainer!
    
    override func setUpWithError() throws {
        // Setup in-memory SwiftData container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: UserLevelProgress.self, MoveHistory.self, configurations: config)
        
        levelViewModel = LevelViewModel(modelContext: container.mainContext)
        // Ensure levels are loaded
        if levelViewModel.levels.isEmpty {
           levelViewModel.loadLevelsFromJSON()
        }
    }

    func testStandardPruning() {
        // Use Level 1 (Classic/Standard)
        viewModel = SudokuGameViewModel(levelID: 1, levelViewModel: levelViewModel)
        
        // Find empty cells at R0C0, R0C8, R8C0 for testing
        // Note: Detailed positions depend on the actual Level 1 data. 
        // For robustness, we will create a BLANK board scenario or rely on finding specific indices that are empty.
        // Or we can manually override the board for testing purposes if the VM allows, or just find ANY empty configuration that fits.
        
        // Let's rely on finding appropriate indices dynamically to be safe against Level 1 data changes.
        // We need:
        // - Anchor: R0C0 (Index 0) -> Must be empty
        // - Target Row: R0C8 (Index 8) -> Must be empty
        // - Target Col: R8C0 (Index 72) -> Must be empty
        
        // If Level 1 has clues there, this test might need adjustment.
        // Let's assume for unit test we can just clear the board/cells to 0 for specific test control, 
        // or safer: Use an index that IS empty.
        
        // Strategy: Inspect the 'cells' and find a row that has at least 2 empty spots.
        let emptyIndices = viewModel.cells.indices.filter { viewModel.cells[$0].value == 0 && !viewModel.cells[$0].isClue }
        
        guard let anchor = emptyIndices.first else {
            XCTFail("No empty cells in level 1")
            return
        }
        
        let row = anchor / 9
        let col = anchor % 9
        
        // Find a neighbor in same ROW
        let rowNeighbor = emptyIndices.first { $0 != anchor && ($0 / 9) == row }
        // Find a neighbor in same COL
        let colNeighbor = emptyIndices.first { $0 != anchor && ($0 % 9) == col }
        
        guard let rNeighbor = rowNeighbor, let cNeighbor = colNeighbor else {
             print("Skipping specific row/col test due to lack of empty neighbors in Level 1 configuration")
             return
        }
        
        // 1. Setup: Add notes to neighbors
        viewModel.selectCell(rNeighbor)
        viewModel.toggleNoteMode()
        viewModel.didTapNumber(1) // Note '1'
        viewModel.didTapNumber(2) // Note '2' (Safety check)
        
        viewModel.selectCell(cNeighbor)
        // Note Mode is still on
        viewModel.didTapNumber(1) // Note '1'
        
        XCTAssertTrue(viewModel.cells[rNeighbor].notes.contains(1))
        XCTAssertTrue(viewModel.cells[rNeighbor].notes.contains(2))
        XCTAssertTrue(viewModel.cells[cNeighbor].notes.contains(1))
        
        // 2. Action: Place '1' at anchor
        viewModel.selectCell(anchor)
        viewModel.toggleNoteMode() // Turn OFF note mode
        viewModel.didTapNumber(1)
        
        // 3. Assertions
        XCTAssertEqual(viewModel.cells[anchor].value, 1)
        
        // Pruning Check
        XCTAssertFalse(viewModel.cells[rNeighbor].notes.contains(1), "Note '1' should be removed from row neighbor")
        XCTAssertTrue(viewModel.cells[rNeighbor].notes.contains(2), "Note '2' should remain")
        
        XCTAssertFalse(viewModel.cells[cNeighbor].notes.contains(1), "Note '1' should be removed from col neighbor")
        
        // 4. Undo Check
        viewModel.undo()
        XCTAssertEqual(viewModel.cells[anchor].value, 0)
        XCTAssertTrue(viewModel.cells[rNeighbor].notes.contains(1), "Undo should restore Note '1'")
        XCTAssertTrue(viewModel.cells[cNeighbor].notes.contains(1), "Undo should restore Note '1'")
    }
    
    func testNonConsecutivePruning() {
        // Use Level 2 (Non-Consecutive)
        viewModel = SudokuGameViewModel(levelID: 2, levelViewModel: levelViewModel)
        
        guard viewModel.isNonConsecutive else {
            XCTFail("Level 2 should be Non-Consecutive")
            return
        }
        
        // Find an empty anchor with an empty orthogonal neighbor
        // Let's try to find an index where index+1 (Right) is also empty
        let emptyIndices = viewModel.cells.indices.filter { viewModel.cells[$0].value == 0 && !viewModel.cells[$0].isClue }
        
        var anchor: Int?
        var neighbor: Int?
        
        for idx in emptyIndices {
            // check Right neighbor
            let right = idx + 1
            if (right / 9) == (idx / 9) && emptyIndices.contains(right) {
                anchor = idx
                neighbor = right
                break
            }
        }
        
        guard let idx = anchor, let nIdx = neighbor else {
            XCTFail("Could not find suitable empty neighbors in Level 2")
            return
        }
        
        // 1. Setup: Add Note '6' and '4' to neighbor
        viewModel.selectCell(nIdx)
        viewModel.toggleNoteMode() // On
        viewModel.didTapNumber(4)
        viewModel.didTapNumber(6)
        viewModel.didTapNumber(8) // Control
        
        XCTAssertTrue(viewModel.cells[nIdx].notes.contains(4))
        XCTAssertTrue(viewModel.cells[nIdx].notes.contains(6))
        XCTAssertTrue(viewModel.cells[nIdx].notes.contains(8))
        
        // 2. Action: Place '5' at anchor
        viewModel.selectCell(idx)
        viewModel.toggleNoteMode() // Off
        viewModel.didTapNumber(5)
        
        // 3. Assertions
        // In Non-Consecutive, placing 5 should prune 4 and 6 from orthogonal neighbors
        XCTAssertFalse(viewModel.cells[nIdx].notes.contains(4), "Note '4' (N-1) should be pruned")
        XCTAssertFalse(viewModel.cells[nIdx].notes.contains(6), "Note '6' (N+1) should be pruned")
        XCTAssertTrue(viewModel.cells[nIdx].notes.contains(8), "Note '8' should remain")
        
        // 4. Undo Check
        viewModel.undo()
        XCTAssertTrue(viewModel.cells[nIdx].notes.contains(4), "Undo should restore 4")
        XCTAssertTrue(viewModel.cells[nIdx].notes.contains(6), "Undo should restore 6")
    }
}
