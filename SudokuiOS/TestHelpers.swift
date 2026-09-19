#if canImport(XCTest)
import XCTest
@testable import SudokuiOS

/// Universal test helpers for Sudoku testing
/// Provides common utilities to fix broken test files
extension XCTestCase {
    
    // MARK: - Board Helpers
    
    /// Create an empty 9x9 board filled with zeros
    static func emptyBoard() -> [[Int]] {
        return Array(repeating: Array(repeating: 0, count: 9), count: 9)
    }
    
    /// Convert 2D board to flat 1D array for validator
    func flattenBoard(_ board: [[Int]]) -> [Int] {
        return board.flatMap { $0 }
    }
    
    /// Convert flat array back to 2D board
    func unflattenBoard(_ flatBoard: [Int]) -> [[Int]] {
        var board: [[Int]] = []
        for row in 0..<9 {
            let start = row * 9
            let end = start + 9
            board.append(Array(flatBoard[start..<end]))
        }
        return board
    }
    
    // MARK: - Validation Helpers
    
    /// Simulate placing a value and validate the move
    /// This replaces the non-existent `validator.isValidMove()` method
    func validateMove(
        board: [[Int]],
        row: Int,
        col: Int,
        val: Int,
        rules: [SudokuRule] = [.classic]
    ) -> Bool {
        var flatBoard = flattenBoard(board)
        flatBoard[row * 9 + col] = val
        return SudokuValidator().validate(board: flatBoard, rules: rules)
    }
    
    /// Validate an entire board with given rules
    func validateBoard(_ board: [[Int]], rules: [SudokuRule] = [.classic]) -> Bool {
        let flatBoard = flattenBoard(board)
        return SudokuValidator().validate(board: flatBoard, rules: rules)
    }
    
    // MARK: - Board Building Helpers
    
    /// Fill a row with values
    mutating func fillRow(_ board: inout [[Int]], row: Int, values: [Int]) {
        guard row >= 0 && row < 9 && values.count <= 9 else { return }
        for (col, val) in values.enumerated() where col < 9 {
            board[row][col] = val
        }
    }
    
    /// Fill a column with values
    mutating func fillColumn(_ board: inout [[Int]], col: Int, values: [Int]) {
        guard col >= 0 && col < 9 && values.count <= 9 else { return }
        for (row, val) in values.enumerated() where row < 9 {
            board[row][col] = val
        }
    }
}

#endif
