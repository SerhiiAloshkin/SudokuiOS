import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Player Guide")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .padding(.top, 20)
                        .padding(.horizontal)
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 20) {
                        GuideSection(title: "Controls & Selection", icon: "hand.tap.fill") {
                            GuideItem(icon: "hand.point.up.fill", title: "Tap to Select", description: "Select a single cell to focus your input.")
                            GuideItem(icon: "hand.draw.fill", title: "Drag to Multi-Select", description: "Slide your finger across the grid to select multiple cells. Any input applies to all selected cells at once!")
                        }
                        
                        GuideSection(title: "Input Modes", icon: "square.and.pencil") {
                            GuideItem(icon: "pencil.line", title: "Pen Mode", description: "Enter final digits. When a cell is certain, use Pen mode.")
                            GuideItem(icon: "pencil", title: "Pencil (Notes)", description: "Enter small candidate numbers. **Smart Notes:** Placing a Pen digit automatically clears that number from neighboring notes (row, column, 3x3 box).")
                            GuideItem(icon: "paintpalette.fill", title: "Palette (Colors)", description: "Apply background colors to cells. Essential for tracking advanced patterns and logic.")
                        }
                        
                        GuideSection(title: "Toolbar Actions", icon: "hammer.fill") {
                            HStack(spacing: 15) {
                                ActionIcon(icon: "arrow.uturn.backward", label: "Undo")
                                ActionIcon(icon: "arrow.uturn.forward", label: "Redo")
                                ActionIcon(icon: "eraser.fill", label: "Erase")
                                ActionIcon(icon: "lightbulb.fill", label: "Hint")
                            }
                            .padding(.vertical, 5)
                            
                            Text("The **Hint** button analyzes the current board state and provides a logical step for your selected cell.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        
                        GuideSection(title: "Sudoku Variants", icon: "circle.grid.3x3.fill") {
                            VStack(alignment: .leading, spacing: 15) {
                                VariantItem(type: .killer, description: "Dashed cages have a target sum. Digits cannot repeat in a cage and must sum to the target.")
                                VariantItem(type: .arrow, description: "Digits along an arrow's path must sum to the value in the circle bulb.")
                                VariantItem(type: .thermo, description: "Digits must strictly increase from the bulb to the tip.")
                                VariantItem(type: .kropki, description: "White dot = consecutive. Black dot = ratio of 2. No dot = nothing.")
                                VariantItem(type: .sandwich, description: "Sum of digits between 1 and 9 in that row or column.")
                                VariantItem(type: .oddEven, description: "Specially marked cells contain only Odd (Square) or Even (Circle) digits.")
                                VariantItem(type: .knight, description: "Cells a Knight's move apart cannot contain the same digit.")
                                VariantItem(type: .king, description: "Adjacent cells (including diagonals) cannot contain the same digit.")
                                VariantItem(type: .nonConsecutive, description: "Orthogonally adjacent cells cannot be consecutive.")
                            }
                        }
                        
                        GuideSection(title: "Level Builder", icon: "plus.square.dashed") {
                            GuideItem(icon: "scissors", title: "Draw Shapes", description: "Drag to define Thermo paths or Arrow sequences.")
                            GuideItem(icon: "square.dashed", title: "Killer Cages", description: "Tap to select a cell, then tap adjacent cells to expand the cage.")
                            GuideItem(icon: "number.square.fill", title: "Sandwich Clues", description: "Set sum targets on the outer grid perimeter.")
                            
                            Text("The **Verification Engine** ensures every level has a logical human solution before it can be saved.")
                                .font(.footnote)
                                .italic()
                                .foregroundColor(.secondary)
                                .padding(.top, 5)
                        }
                        
                        GuideSection(title: "Expert Settings", icon: "gearshape.2.fill") {
                            GuideItem(icon: "selection.pin.in.out", title: "Highlight Mode", description: "**Restriction** mode highlights digits that conflict with your selection. **Selection** mode focuses on your current UI selection.")
                            GuideItem(icon: "line.3.horizontal.decrease.circle", title: "Auto-Filter", description: "Automatically hides impossible note combinations for Killer Cages and Sandwiches.")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .fontWeight(.bold)
            }
        }
    }
}

private struct GuideSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(.themeBlue)
                Text(title.uppercased())
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(20)
        }
    }
}

private struct GuideItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 32)
                .foregroundColor(.themeBlue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct VariantItem: View {
    let type: SudokuRuleType
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: type.iconName)
                .font(.title3)
                .frame(width: 32)
                .foregroundColor(.themeBlue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct ActionIcon: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 44, height: 44)
                .background(Color.themeBlue.opacity(0.1))
                .clipShape(Circle())
                .foregroundColor(.themeBlue)
            
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationView {
        HowToPlayView()
    }
}
