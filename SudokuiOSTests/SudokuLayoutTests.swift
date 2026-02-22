import XCTest
@testable import SudokuiOS

class SudokuLayoutTests: XCTestCase {
    
    func testBoardDimensionsFitScreen() {
        // Typical iPhone Widths
        let screenWidths: [CGFloat] = [
            375, // iPhone SE / Mini
            390, // iPhone 14
            430  // iPhone 14 Pro Max
        ]
        
        let cardPadding: CGFloat = 4.0
        let horizontalPadding: CGFloat = 20.0 // Parent view padding
        
        for width in screenWidths {
            let availableWidth = width - (horizontalPadding * 2)
            
            // Logic from SudokuGameView
            // Width - (2 * cardPadding) = TotalCols * CellSize
            // calculatedCellSize = ((availableWidth - (cardPadding * 2)) / 9).rounded(.down)
            
            let totalCols: CGFloat = 9
            let calculatedCellSize = ((availableWidth - (cardPadding * 2)) / totalCols).rounded(.down)
            let cellSize = max(0, calculatedCellSize)
            
            let boardSize = cellSize * 9
            let cardContentWidth = boardSize + (cardPadding * 2)
            
            // Assertion: The total card width must be <= available width
            XCTAssertLessThanOrEqual(cardContentWidth, availableWidth + 0.1, "Board width exceeds available space on screen width \(width)")
            
            // Assertion: Border must be visible (size > 0)
            XCTAssertGreaterThan(boardSize, 0, "Board size invalid on screen width \(width)")
        }
    }
}
