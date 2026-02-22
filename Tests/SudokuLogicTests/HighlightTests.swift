import XCTest
import SwiftUI
@testable import SudokuLogic

@MainActor
class HighlightTests: XCTestCase {
    
    func testAssetColorsExist() {
        // Verify that the assets we created can be loaded.
        // If they don't exist, Color("name") doesn't crash but returns clear/black depending on context,
        // but explicit UIColor(named:) returns nil.
        
        let selectionColor = UIColor(named: "SelectionHighlight")
        XCTAssertNotNil(selectionColor, "SelectionHighlight color set should exist")
        
        let noteColor = UIColor(named: "NoteHighlight")
        XCTAssertNotNil(noteColor, "NoteHighlight color set should exist")
    }
}
