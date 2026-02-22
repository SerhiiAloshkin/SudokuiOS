import Foundation

struct LevelVariantHelper {
    
    /// Returns the set of invalid positions relative to a center point for a given rule type.
    /// Used for visualizing "restricted" cells in the tutorial.
    static func getInvalidPositions(for rule: SudokuRuleType, from center: (row: Int, col: Int)) -> [(row: Int, col: Int)] {
        var moves: [(row: Int, col: Int)] = []
        let (r, c) = center
        
        switch rule {
        case .knight:
            let offsets = [
                (-2, -1), (-2, 1),
                (-1, -2), (-1, 2),
                (1, -2), (1, 2),
                (2, -1), (2, 1)
            ]
            for (dr, dc) in offsets {
                let nr = r + dr
                let nc = c + dc
                if isValidCoordinate(nr, nc) {
                    moves.append((nr, nc))
                }
            }
            
        case .king:
            let offsets = [
                (-1, -1), (-1, 0), (-1, 1),
                (0, -1),           (0, 1),
                (1, -1),  (1, 0),  (1, 1)
            ]
            for (dr, dc) in offsets {
                let nr = r + dr
                let nc = c + dc
                if isValidCoordinate(nr, nc) {
                    moves.append((nr, nc))
                }
            }
            
        default:
            break
        }
        
        return moves
    }
    
    private static func isValidCoordinate(_ r: Int, _ c: Int) -> Bool {
        return r >= 0 && r < 9 && c >= 0 && c < 9
    }
}
