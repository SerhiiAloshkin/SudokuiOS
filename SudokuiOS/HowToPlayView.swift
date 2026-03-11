import SwiftUI

struct HowToPlayView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("The Versa Encyclopedia")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .padding(.top, 20)
                        .padding(.horizontal)
                        .foregroundColor(.primary)
                    
                    Text("Every tool, interaction, and rule explained.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, -15)
                    
                    VStack(spacing: 16) {
                        GameScreenSection()
                        NumpadSection()
                        ActionsSection()
                        VariantsSection()
                        BuilderSection()
                        SettingsSection()
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

// MARK: - Sections

private struct GameScreenSection: View {
    var body: some View {
        EncyclopediaCard(title: "Game Screen & Controls", icon: "display") {
            EncyclopediaItem(icon: "house.fill", title: "Home", description: "Saves your current session and returns to the Main Menu.")
            EncyclopediaItem(icon: "stopwatch.fill", title: "Timer", description: "Tracks your solving progress. Pause to stop the clock.")
            EncyclopediaItem(icon: "pause.fill", title: "Pause", description: "Halts the timer and hides the board to prevent peaking!")
            
            Divider().padding(.vertical, 4)
            
            EncyclopediaItem(icon: "hand.tap.fill", title: "Tap to Select", description: "Tap a cell to focus your input.")
            EncyclopediaItem(icon: "hand.draw.fill", title: "Drag to Multi-Select", description: "Swipe across the grid to select multiple cells. Your inputs will apply to all selected cells simultaneously.")
        }
    }
}

private struct NumpadSection: View {
    var body: some View {
        EncyclopediaCard(title: "Numpad & Input Modes", icon: "number.square.fill") {
            EncyclopediaItem(icon: "pencil.line", title: "Pen Mode", description: "Enters final large digits. Use this when you are certain of a value.")
            EncyclopediaItem(icon: "pencil", title: "Pencil (Notes)", description: "Enters small candidate digits for tracking possibilities.")
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.themeBlue)
                    Text("Smart Notes").fontWeight(.bold)
                }
                Text("Placing a Pen digit automatically erases that number from notes in its row, column, and 3x3 box.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 44)
            
            EncyclopediaItem(icon: "paintpalette.fill", title: "Palette Mode", description: "Applies background colors to cells. Essential for advanced logical techniques like 'Coloring'.")
            
            EncyclopediaItem(icon: "square.on.square.fill", title: "Multi-Select Shortcut", description: "Long-press the 'Multi' button to select all remaining empty cells on the board instantly.")
        }
    }
}

private struct ActionsSection: View {
    var body: some View {
        EncyclopediaCard(title: "Toolbar & Actions", icon: "hammer.fill") {
            EncyclopediaItem(icon: "arrow.uturn.backward", title: "Undo", description: "Reverts your very last action (digit, note, or color).")
            EncyclopediaItem(icon: "arrow.uturn.forward", title: "Redo", description: "Re-applies an action you just reverted.")
            EncyclopediaItem(icon: "eraser.fill", title: "Erase", description: "Clears digits, notes, and colors from your selected cell(s).")
            EncyclopediaItem(icon: "lightbulb.fill", title: "Hint", description: "Analyzes the board logically and provides a step-by-step deduction to help you progress.")
            
            EncyclopediaItem(icon: "multiply", title: "Cross (Sandwich)", description: "In Sandwich levels, use the Cross tool to mark cells that definitely CANNOT be a 1 or a 9.\n**Shortcut:** Long-press to cross all empty cells.")
        }
    }
}

private struct VariantsSection: View {
    var body: some View {
        EncyclopediaCard(title: "Sudoku Variants (Rules)", icon: "list.bullet.rectangle.fill") {
            VStack(alignment: .leading, spacing: 15) {
                VariantDocItem(type: .killer, description: "Cages must sum to the small total in the corner. Digits cannot repeat within a cage.")
                VariantDocItem(type: .arrow, description: "Digits along the arrow line must sum to the value inside its bulb.")
                VariantDocItem(type: .thermo, description: "Digits must strictly increase starting from the bulb to the tip.")
                VariantDocItem(type: .kropki, description: "White dot = consecutive digits (e.g. 4-5). Black dot = double ratio (e.g. 4-8).")
                VariantDocItem(type: .sandwich, description: "Clues outside the grid show the sum of digits trapped between the 1 and the 9.")
                VariantDocItem(type: .oddEven, description: "Squares contain Even digits (2,4,6,8). Circles contain Odd digits (1,3,5,7,9).")
                VariantDocItem(type: .knight, description: "Digits a chess Knight's move apart cannot be identical.")
                VariantDocItem(type: .king, description: "Digits in diagonally touching cells cannot be identical.")
                VariantDocItem(type: .nonConsecutive, description: "Orthogonally adjacent cells cannot contain digits that are consecutive (e.g. 3 next to 4).")
            }
        }
    }
}

private struct BuilderSection: View {
    var body: some View {
        EncyclopediaCard(title: "Level Builder", icon: "plus.square.dashed") {
            EncyclopediaItem(icon: "hand.draw.fill", title: "Drawing Shapes", description: "For Thermos and Arrows, tap the starting bulb and drag across the path you want to create.")
            EncyclopediaItem(icon: "square.dashed", title: "Building Cages", description: "Tap a cell, then tap its neighbors to expand. Tap the cage sum at any time to edit the target.")
            EncyclopediaItem(icon: "circle.grid.2x1.fill", title: "Placing Dots", description: "Tap the Kropki tool, select White or Black, then tap two adjacent cells to link them.")
            EncyclopediaItem(icon: "number.square", title: "Sandwich Clues", description: "Tap the slots around the perimeter of the grid to enter sums (must be 0 or 2-35).")
            
            EncyclopediaItem(icon: "checkmark.seal.fill", title: "Verification", description: "Every custom level is verified by a logical solver to guarantee it is 100% uniquely solvable.")
        }
    }
}

private struct SettingsSection: View {
    var body: some View {
        EncyclopediaCard(title: "Game Settings", icon: "gearshape.fill") {
            EncyclopediaItem(icon: "paintbrush.fill", title: "Theme", description: "Choose between Light or Dark mode, or select 'System' to follow your device's appearance settings.")
            
            Divider().padding(.vertical, 4)
            
            Group {
                Text("Highlight Mode")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.themeBlue)
                
                EncyclopediaItem(icon: "highlighter", title: "None", description: "Disables all highlighting for a pure paper Sudoku experience.")
                EncyclopediaItem(icon: "selection.pin.in.out", title: "Selection", description: "Highlights only the currently selected cell(s).")
                EncyclopediaItem(icon: "viewfinder", title: "Restriction", description: "(Recommended) Highlights the selected cell's row, column, and 3x3 box, as well as all matching digits across the board.")
            }
            
            Divider().padding(.vertical, 4)
            
            Group {
                Text("Show Mistakes")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.themeBlue)
                
                EncyclopediaItem(icon: "exclamationmark.triangle.fill", title: "Immediate", description: "Flags conflicting or mathematically incorrect digits in red the moment they are entered.")
                EncyclopediaItem(icon: "checkmark.circle.fill", title: "When Board Full", description: "Only reveals errors once you have completely filled all 81 cells.")
                EncyclopediaItem(icon: "prohibited", title: "Never", description: "The game will never flag errors. Use this for a truly 'Hardcore' challenge.")
            }
            
            Divider().padding(.vertical, 4)
            
            EncyclopediaItem(icon: "slider.horizontal.3", title: "Auto-filter Combinations", description: "When enabled, the game automatically removes mathematically impossible notes inside Killer Cages and Sandwiches based on the target sums.")
            
            Divider().padding(.vertical, 4)
            
            Group {
                Text("Hint Target")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.themeBlue)
                
                EncyclopediaItem(icon: "scope", title: "Selected Cell", description: "Using a hint will attempt to find a logical deduction specifically for the cell you currently have highlighted.")
                EncyclopediaItem(icon: "target", title: "Random Cell", description: "The engine will look at the entire board and reveal the next easiest logical step anywhere on the grid.")
            }
        }
    }
}

// MARK: - Reusable Components

private struct EncyclopediaCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(.top, 16)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundColor(.themeBlue)
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
    }
}

private struct EncyclopediaItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundColor(.themeBlue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct VariantDocItem: View {
    let type: SudokuRuleType
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: type.iconName)
                .font(.title3)
                .frame(width: 28)
                .foregroundColor(.themeBlue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    NavigationView {
        HowToPlayView()
    }
}
