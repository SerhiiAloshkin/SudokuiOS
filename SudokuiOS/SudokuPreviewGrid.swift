import SwiftUI

struct SudokuPreviewGrid: View {
    let currentBoard: String
    let initialBoard: String? // To distinguish clues
    
    // Grid Setup
    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(0..<81, id: \.self) { index in
                let val = getValue(at: index, in: currentBoard)
                let isClue = isClue(at: index)
                
                ZStack {
                    // Border handled by overlay on grid or individual cells
                    Rectangle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        .background(Color(uiColor: .systemBackground))
                    
                    if val != 0 {
                        Text("\(val)")
                            .font(.system(size: 16, weight: isClue ? .bold : .regular))
                            .foregroundColor(isClue ? .primary : .blue)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .overlay(
            LevelGridPattern()
                .stroke(Color.primary, lineWidth: 2)
        )
        .border(Color.primary, width: 2)
    }
    
    private func getValue(at index: Int, in board: String) -> Int {
        guard index < board.count else { return 0 }
        let charIndex = board.index(board.startIndex, offsetBy: index)
        return Int(String(board[charIndex])) ?? 0
    }
    
    private func isClue(at index: Int) -> Bool {
        guard let initial = initialBoard, index < initial.count else { return true } // Assume clue if no initial board known? Or false.
        // If initial provided, non-zero means clue
        let initialVal = getValue(at: index, in: initial)
        return initialVal != 0
    }
}
