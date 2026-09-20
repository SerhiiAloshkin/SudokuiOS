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
            EncyclopediaItem(icon: "questionmark.circle.fill", title: "Rules", description: "Opens the rule pages for this level's active variants. Tap \"Full Guide\" inside it to open this Encyclopedia without leaving your level.")
            EncyclopediaItem(icon: "stopwatch.fill", title: "Timer", description: "Tracks your solving progress. Pause to stop the clock.")
            EncyclopediaItem(icon: "pause.fill", title: "Pause", description: "Halts the timer and hides the board. Offers Continue, Reset Level (asks for confirmation), and Close Level.")
            EncyclopediaItem(icon: "gearshape.fill", title: "Settings", description: "Opens highlight, gameplay, appearance, and support settings without leaving your level.")

            Divider().padding(.vertical, 4)
            
            EncyclopediaItem(icon: "hand.tap.fill", title: "Tap to Select", description: "Tap a cell to focus your input.")
            EncyclopediaItem(icon: "hand.draw.fill", title: "Drag to Multi-Select", description: "Swipe across the grid to select multiple cells. Your inputs will apply to all selected cells simultaneously.")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "rectangle.3.group.fill")
                        .foregroundColor(.themeBlue)
                    Text("Highlighting With Multiple Cells Selected").fontWeight(.bold)
                }
                Text("With 2 or more cells selected, highlighting switches from \"where can this number go\" to \"which cells are related to every selected cell\" — same row, column, or box as all of them. This is useful for finding cells where a candidate shared by your selected cells can be safely erased from notes, but it means Potential-mode highlighting (showing valid spots for a number) only works with a single cell selected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 44)
        }
    }
}

private struct NumpadSection: View {
    var body: some View {
        EncyclopediaCard(title: "Numpad & Input Modes", icon: "number.square.fill") {
            EncyclopediaItem(icon: "pencil.slash", title: "Pen Mode", description: "Enters final large digits. Use this when you are certain of a value.")
            EncyclopediaItem(icon: "pencil.circle.fill", title: "Pencil (Notes)", description: "Enters small candidate digits for tracking possibilities.")
            
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
            
            EncyclopediaItem(icon: "paintpalette.fill", title: "Palette Mode", description: "Applies background colors to cells. Essential for advanced logical techniques like 'Coloring'. Tap the circle-slash swatch to clear a cell's color.")

            EncyclopediaItem(icon: "square.on.square.fill", title: "Multi-Select Shortcut", description: "Long-press the 'Multi' button to select all remaining empty cells on the board instantly.")

            EncyclopediaItem(icon: "1.square.fill", title: "\"19\" Button", description: "Appears only on Sandwich levels. Adds or removes notes for 1 and 9 across your selected empty cells, based on where each is currently a valid candidate.")

            EncyclopediaItem(icon: "circle.slash", title: "Greyed-Out Digits", description: "A number dims once you've placed it 9 times on the board. Turn off \"Disable Completed Digits\" in Settings to keep using it anyway.")
        }
    }
}

private struct ActionsSection: View {
    var body: some View {
        EncyclopediaCard(title: "Toolbar & Actions", icon: "hammer.fill") {
            EncyclopediaItem(icon: "arrow.uturn.backward", title: "Undo", description: "Reverts your very last action (digit, note, or color).")
            EncyclopediaItem(icon: "arrow.uturn.forward", title: "Redo", description: "Re-applies an action you just reverted.")
            EncyclopediaItem(icon: "eraser.fill", title: "Erase", description: "Clears digits, notes, and colors from your selected cell(s).")
            EncyclopediaItem(icon: "lightbulb.fill", title: "Hint", description: "Analyzes the board logically and provides a step-by-step deduction to help you progress. Has a 5-minute cooldown after each use, shown as a countdown on the button itself.")

            EncyclopediaItem(icon: "multiply", title: "Cross (Sandwich)", description: "In Sandwich levels, use the Cross tool to mark cells that definitely CANNOT be a 1 or a 9.\n**Shortcut:** Long-press to cross all empty cells.")

            EncyclopediaItem(icon: "list.bullet.rectangle.fill", title: "Combination Helpers", description: "Tap a Sandwich clue number, or select a Killer cage and tap the cage-helper button in the header, to open a list of every remaining valid digit combination for it. Tap an entry to cross it off. Controlled by the \"Show Combination Helpers\" and \"Auto-Filter Combinations\" settings below.")
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
            EncyclopediaItem(icon: "checkmark.circle.fill", title: "Rule Toggles", description: "Classic and Non-Consecutive are mutually exclusive — enabling one turns off the other. King and Knight can be combined freely with either.")

            EncyclopediaItem(icon: "hand.tap.fill", title: "Drawing Shapes", description: "For Thermos, Arrows, and Cages, tap cells one at a time to extend the shape — this is a sequence of taps, not a drag. Each new tap must be adjacent to the shape.")
            EncyclopediaItem(icon: "circle.grid.2x1.fill", title: "Placing Dots", description: "Tap the Kropki tool, select White or Black, then tap two orthogonally-adjacent cells to link them.")
            EncyclopediaItem(icon: "number.square", title: "Sandwich Clues", description: "Tap the slots around the perimeter of the grid to enter sums (must be 0 or 2-35).")

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "eraser.fill")
                        .foregroundColor(.themeBlue)
                    Text("Erasing & Editing Shapes").fontWeight(.bold)
                }
                Text("There's no per-shape edit control — to change or remove a Thermo, Arrow, Cage, or Kropki dot, select the Erase tool and tap any cell it touches; this deletes the entire shape so you can redraw it.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 44)

            EncyclopediaItem(icon: "checkmark.seal.fill", title: "Verification", description: "Tap Validate to run a logical solver over your level — this is optional, not required to save, and confirms the puzzle is human-solvable. It does not guarantee the solution is unique.")

            EncyclopediaItem(icon: "square.and.pencil", title: "Editing an Existing Level", description: "Use the ⋯ menu on a level in My Custom Levels to reopen it here with everything pre-filled, ready to change and re-save.")
        }
    }
}

private struct SettingsSection: View {
    var body: some View {
        EncyclopediaCard(title: "Game Settings", icon: "gearshape.fill") {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: Highlight Mode
                Group {
                    Text("Highlight Mode")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.themeBlue)
                    
                    EncyclopediaItem(icon: "selection.pin.in.out", title: "Minimal Highlight", description: "When On, only the currently selected cell is highlighted. Turn Off to access Detailed Mode.")
                    
                    EncyclopediaItem(icon: "hand.tap.fill", title: "Restriction", description: "(Detailed Mode) Highlights the selected cell's row, column, and 3x3 box, showing all rules affecting that spot.")
                    
                    EncyclopediaItem(icon: "viewfinder", title: "Potential", description: "(Detailed Mode) Visually reveals all valid empty spots where your selected number could be placed.")
                    
                    EncyclopediaItem(icon: "number.circle.fill", title: "Highlight Same Number", description: "Automatically highlights every instance of your selected number across the entire board.")
                    
                    EncyclopediaItem(icon: "square.grid.3x3.fill", title: "Highlight Same Note", description: "Highlights every cell containing the same Pencil note as your current selection.")
                }
                
                Divider()
                
                // MARK: Gameplay
                Group {
                    Text("Gameplay")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.themeBlue)
                    
                    EncyclopediaItem(icon: "exclamationmark.triangle.fill", title: "Show Mistakes", description: "• **Immediately**: Flags errors in red the moment they are entered.\n• **When Board Full**: Only reveals errors once the grid is finished.\n• **Never**: Mistakes are never flagged.")
                    
                    EncyclopediaItem(icon: "3.circle.fill", title: "Enable Mistake Limit", description: "Enforces the 3-strike rule — three incorrect moves ends the game. Turning this off doesn't just skip the game-over: mistakes stop being counted entirely.")

                    EncyclopediaItem(icon: "lightbulb.fill", title: "Show Hint Button", description: "Toggles the visibility of the Hint system on the game screen. Hints are always hidden on custom levels regardless of this setting, since there's no solution to hint from.")

                    EncyclopediaItem(icon: "p.square.fill", title: "Disable Completed Digits", description: "Stops the numpad from greying out and disabling numbers that have been placed 9 times.")

                    EncyclopediaItem(icon: "list.bullet.rectangle.fill", title: "Show Combination Helpers", description: "Displays a list of all remaining mathematical combinations for selected Killer Cages or Sandwich sums, and pre-selects every valid combination by default the first time you open a cage.")
                    
                    EncyclopediaItem(icon: "slider.horizontal.3", title: "Auto-Filter Combinations", description: "Automatically erases candidate notes that are mathematically impossible within a cage or sandwich.")
                    
                    EncyclopediaItem(icon: "target", title: "Hint Target", description: "• **Selected Cell**: Forces the Hint engine to analyze your current focus.\n• **Random Cell**: Finds the single most logical deduction anywhere on the board.")
                }
                
                Divider()
                
                // MARK: Appearance
                Group {
                    Text("Appearance")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.themeBlue)
                    
                    EncyclopediaItem(icon: "paintbrush.fill", title: "Theme", description: "Switch between Light mode, Dark mode, or System (which follows your device appearance).")
                }
                
                Divider()
                
                // MARK: Support
                Group {
                    Text("Support")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.themeBlue)
                    
                    EncyclopediaItem(icon: "envelope.fill", title: "Contact Us", description: "Opens a direct email line to the developers for feedback or bug reports.")
                }
            }
        }
    }
}

// MARK: - Reusable Components

private struct EncyclopediaCard<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let content: Content

    init(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) {
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
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    
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
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: type.iconName)
                .font(.title3)
                .frame(width: 28)
                .foregroundColor(.themeBlue)

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(type.displayName))
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
