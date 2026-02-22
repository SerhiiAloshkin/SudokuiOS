import Foundation

struct HighlightManager {
    // Knight Moves: L-shape jumps (±1, ±2)
    static let knightOffsets: [(Int, Int)] = [
        (-2, -1), (-2, 1),
        (-1, -2), (-1, 2),
        (1, -2), (1, 2),
        (2, -1), (2, 1)
    ]
    
    // King Moves: All 8 adjacent cells (including diagonals)
    static let kingOffsets: [(Int, Int)] = [
        (-1, -1), (-1, 0), (-1, 1),
        (0, -1),           (0, 1),
        (1, -1), (1, 0), (1, 1)
    ]
}
