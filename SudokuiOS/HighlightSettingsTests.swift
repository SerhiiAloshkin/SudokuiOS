#if canImport(XCTest)
import XCTest
import SwiftData
@testable import SudokuiOS

@MainActor
class HighlightSettingsTests: XCTestCase {
    
    var viewModel: SudokuGameViewModel!
    var appSettings: AppSettings!
    var container: ModelContainer!
    
    override func setUp() async throws {
        // Setup in-memory container for AppSettings
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: AppSettings.self, configurations: config)
        
        appSettings = AppSettings()
        container.mainContext.insert(appSettings)
        
        // Setup ViewModel
        // We need a dummy LevelViewModel for parent
        let levelVM = LevelViewModel(modelContext: container.mainContext)
        viewModel = SudokuGameViewModel(levelID: 1, parentViewModel: levelVM)
        viewModel.setSettings(appSettings)
        
        // Initialize dummy board
        // 000...
        viewModel.currentBoard = String(repeating: "0", count: 81)
        viewModel.initializeCells()
    }
    
    func testHighlightSameNumberEnabled() {
        // Setup: Cell 0 has value 5, Cell 1 has value 5
        let cell0 = viewModel.cells[0]
        let cell1 = viewModel.cells[1]
        
        // We simulate value entry via `currentBoard` modification or direct cell mod if easier for test
        // modifying cell.value directly doesn't update String, but getHighlightType uses getCharAt(index) which uses currentBoard
        // So we must update currentBoard.
        var chars = Array(String(repeating: "0", count: 81))
        chars[0] = "5"
        chars[1] = "5"
        viewModel.currentBoard = String(chars)
        
        // Select Cell 0
        viewModel.selectedCellIndex = 0
        
        // 1. Verify Enabled (Default)
        appSettings.isHighlightSameNumberEnabled = true
        XCTAssertEqual(viewModel.getHighlightType(at: 1), .sameValue, "Should highlight same number when enabled")
        
        // 2. Verify Disabled
        appSettings.isHighlightSameNumberEnabled = false
        XCTAssertEqual(viewModel.getHighlightType(at: 1), .none, "Should NOT highlight same number when disabled")
    }
    
    func testHighlightSameNoteEnabled() {
        // Setup: Cell 0 (Empty) has notes {4}
        // Cell 1 (Empty) has notes {4}
        // Cell 2 (Empty) has notes {5}
        
        let cell0 = viewModel.cells[0]
        cell0.notes = [4]
        
        let cell1 = viewModel.cells[1]
        cell1.notes = [4]
        
        let cell2 = viewModel.cells[2]
        cell2.notes = [5]
        
        viewModel.currentBoard = String(repeating: "0", count: 81) // Ensure empty values
        
        // Select Cell 0
        viewModel.selectedCellIndex = 0
        
        // 1. Verify Enabled (Default)
        appSettings.isHighlightSameNoteEnabled = true
        XCTAssertEqual(viewModel.getHighlightType(at: 1), .relating, "Should highlight cell with shared note")
        XCTAssertEqual(viewModel.getHighlightType(at: 2), .none, "Should NOT highlight cell with disjoint notes")
        
        // 2. Verify Disabled
        appSettings.isHighlightSameNoteEnabled = false
        XCTAssertEqual(viewModel.getHighlightType(at: 1), .none, "Should NOT highlight notes when disabled")
    }
    
    func testMixedNotesHighlighting() {
        // Setup: Cell 0 has {1, 2}
        // Cell 1 has {1} -> Should Highlight
        // Cell 2 has {2} -> Should Highlight
        // Cell 3 has {3} -> No Highlight
        
        viewModel.cells[0].notes = [1, 2]
        viewModel.cells[1].notes = [1]
        viewModel.cells[2].notes = [2]
        viewModel.cells[3].notes = [3]
        
        viewModel.selectedCellIndex = 0
        appSettings.isHighlightSameNoteEnabled = true
        
        XCTAssertEqual(viewModel.getHighlightType(at: 1), .relating)
        XCTAssertEqual(viewModel.getHighlightType(at: 2), .relating)
    }

    func testPotentialModeSameNumber() {
        // Setup Potential Mode
        appSettings.highlightMode = .potential
        appSettings.isMinimalHighlight = false
        
        // ... (Rest of test body) ...
        
        let cell0 = viewModel.cells[0]
        let cell1 = viewModel.cells[1]
        
        // Set values: Cell 0=5, Cell 1=5
        var chars = Array(String(repeating: "0", count: 81))
        chars[0] = "5"
        chars[1] = "5"
        viewModel.currentBoard = String(chars)
        
        viewModel.selectedCellIndex = 0
        
        // 1. Enabled
        appSettings.isHighlightSameNumberEnabled = true
        XCTAssertEqual(viewModel.getHighlightType(at: 1), .sameValue, "Potential Mode: Should highlight same number when enabled")
        
        // 2. Disabled
        appSettings.isHighlightSameNumberEnabled = false
        XCTAssertEqual(viewModel.getHighlightType(at: 1), .none, "Potential Mode: Should NOT highlight same number when disabled")
    }
}
#endif
