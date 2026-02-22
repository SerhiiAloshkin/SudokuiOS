import SwiftUI

struct LevelIconsInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    // Legend Data
    private let legends: [(icon: String, title: String, description: String)] = [
        ("square.grid.3x3.fill", "Classic Sudoku", "Standard 9x9 Sudoku grid."),
        ("squareshape.split.2x2", "Non-Consecutive", "Adjacent cells cannot contain consecutive numbers."),
        ("square.stack.3d.up", "Sandwich Sudoku", "Clues indicate sums between 1 and 9."),
        ("thermometer", "Thermo Sudoku", "Digits increase along thermometer shapes."),
        ("arrow.up.forward.circle", "Arrow Sudoku", "Digits along the arrow sum to the number in the circle."),
        ("square.dashed", "Killer Sudoku", "Numbers in cages must sum to the small top-left clue."),
        ("kropki_icon", "Kropki Sudoku", "White dot: Consecutive. Black dot: Ratio 1:2. Negative constraint applies!"),
        ("odd_even_icon", "Odd-Even Sudoku", "Gray Circle: Odd (1,3,5...). Gray Square: Even (2,4,6...)."),
        ("knight_icon", "Knight Sudoku", "Cells a knight's move away (L-shape) cannot contain the same number."),
        ("crown.fill", "King Sudoku", "Adjacent cells (including diagonals) cannot contain the same number.")
    ]
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Game Types")) {
                    ForEach(legends, id: \.title) { item in
                        HStack(spacing: 16) {
                            Group {
                                if item.icon == "kropki_icon" {
                                    HStack(spacing: 1) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 10))
                                        Image(systemName: "circle")
                                            .font(.system(size: 10))
                                    }
                                    .frame(width: 30)
                                } else if item.icon == "odd_even_icon" {
                                    HStack(spacing: 1) {
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                        Image(systemName: "square.fill")
                                            .font(.system(size: 10))
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 30)
                                } else if item.icon == "knight_icon" {
                                    Image("knight_icon")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                } else {
                                    Image(systemName: item.icon)
                                        .font(.title2)
                                        .frame(width: 30)
                                }
                            }
                            .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                

            }
            .navigationTitle("Level Icons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LevelIconsInfoView()
}
