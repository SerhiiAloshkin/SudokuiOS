import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Play")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .padding(.bottom, 10)
                        .foregroundColor(.primary)
                    
                    SectionA()
                    SectionB()
                    SectionC()
                    SectionD()
                }
                .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct SectionA: View {
    var body: some View {
        DisclosureGroup(
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("**Goal:** Fill the 9x9 grid so every row, column, and 3x3 box contains digits 1-9 exactly once.")
                    
                    Text("**Selection:** Tap a cell to select it. Drag your finger across the board to select multiple cells at once! Any digit or color you input will apply to all selected cells simultaneously.")
                }
                .font(.body)
                .padding(.vertical, 8)
                .foregroundColor(.secondary)
            },
            label: {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(.blue)
                    Text("Basics & Controls")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
        )
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

private struct SectionB: View {
    var body: some View {
        DisclosureGroup(
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        Text("**Pen (Digit):** Enters final large digits.")
                        
                        Text("**Pencil (Notes):** Enters small candidate numbers. **Smart Notes:** If you place a large Pen digit, that same digit is automatically erased from all Pencil notes in its row, column, and 3x3 box.")
                        
                        Text("**Palette (Colors):** Applies background colors to cells. Great for advanced coloring logic.")
                        
                        Text("**Toolbar:** Use Undo/Redo for mistakes, Erase to clear a cell, and Hint to apply a logical step to your currently selected cell.")
                    }
                }
                .font(.body)
                .padding(.vertical, 8)
                .foregroundColor(.secondary)
            },
            label: {
                HStack {
                    Image(systemName: "pencil.and.outline")
                        .foregroundColor(.blue)
                    Text("Input Modes & Tools")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
        )
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

private struct SectionC: View {
    var body: some View {
        DisclosureGroup(
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    RuleItem(type: .killer, description: "Dashed cages have a target sum in the top-left. Digits inside a cage cannot repeat and must add up to the sum.")
                    RuleItem(type: .arrow, description: "Digits along an arrow's path must sum to the value in the arrow's circle. Digits can repeat on the path.")
                    RuleItem(type: .thermo, description: "Digits must strictly increase starting from the bulb to the tip of the thermometer (e.g., 2-5-7-9).")
                    RuleItem(type: .kropki, description: "A white dot between cells means their digits are consecutive (differ by 1). A black dot means one digit is exactly double the other. (No dot means there is no restriction).")
                    RuleItem(type: .sandwich, description: "Numbers around the outside of the grid show the sum of the digits \"sandwiched\" between the 1 and the 9 in that row or column.")
                    RuleItem(type: .oddEven, description: "Specially marked cells (squares/circles) can only contain Odd (1,3,5,7,9) or Even (2,4,6,8) digits.")
                    RuleItem(type: .knight, description: "Cells that are a chess Knight's move apart cannot contain the same digit.")
                    RuleItem(type: .king, description: "Cells that touch diagonally cannot contain the same digit.")
                    RuleItem(type: .nonConsecutive, description: "Orthogonally adjacent cells (up, down, left, right) cannot contain consecutive digits (e.g., 4 cannot be next to 3 or 5).")
                }
                .padding(.vertical, 8)
            },
            label: {
                HStack {
                    Image(systemName: "list.bullet.rectangle.fill")
                        .foregroundColor(.blue)
                    Text("Sudoku Variants (Rules)")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
        )
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

private struct RuleItem: View {
    let type: SudokuRuleType
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: type.iconName)
                .font(.title3)
                .frame(width: 30)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct SectionD: View {
    var body: some View {
        DisclosureGroup(
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("**Builder:** Draw shapes by dragging. For Killer cages, tap a starting cell, then tap orthogonally adjacent cells to expand the cage. Sandwich clues are entered on the perimeter slots.")
                    
                    Text("**Verification:** The builder uses a logical solver. It might reject levels that technically have a solution if they require extreme human-only logic not covered by the engine.")
                    
                    Text("**Highlight Mode:** In Settings, \"Restriction\" mode is highly recommended. It highlights the selected digit everywhere, plus its row, column, and box.")
                    
                    Text("**Auto-Filter:** When turned On, the game helps eliminate mathematically impossible note combinations in Killer cages and Sandwiches. Turn Off for a hardcore experience.")
                }
                .font(.body)
                .padding(.vertical, 8)
                .foregroundColor(.secondary)
            },
            label: {
                HStack {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(.blue)
                    Text("Level Builder & Settings")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
        )
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        HowToPlayView()
    }
}
