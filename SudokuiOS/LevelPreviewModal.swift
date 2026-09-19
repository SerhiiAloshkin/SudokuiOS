import SwiftUI

struct LevelPreviewModal: View {
    let level: SudokuLevel
    @ObservedObject var viewModel: LevelViewModel // To call reset
    
    // Actions needed to trigger navigation from Parent
    var onPlay: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Level \(level.id)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color("ThemeBlue"))
                    
                    // Variant Label(s) with Icons (ViewThatFits)
                    let rules = level.types.isEmpty ? [level.ruleType] : level.types
                    RulesListView(rules: rules)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Preview Board
                // User requirement: "Initial puzzle numbers only" (Implemented previously)
                LevelPreviewBoard(level: level)
                    .frame(maxWidth: 300) // Constrain width
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(uiColor: .systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                    .padding()
                    .opacity(level.isLocked ? 0.5 : 1.0) // Dim if locked
                    .overlay(
                        Group {
                            if level.isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                                    .shadow(radius: 2)
                            }
                        }
                    )
                
                // Status Section
                if level.isSolved {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Solved: \(formatTime(seconds: Int(level.lastSolvedTime)))")
                                .fontWeight(.semibold)
                        }
                        
                        if level.mistakesMade == 0 {
                            Text("✨ Perfect Run ✨")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Mistakes: \(level.mistakesMade)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if level.bestTime > 0 {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                Text("Best: \(formatTime(seconds: Int(level.bestTime)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                } else if level.userProgress != nil && !level.isLocked {
                    // In Progress
                    Text("In Progress • \(formatTime(seconds: level.timeElapsed))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else if level.isLocked {
                    Text("Locked")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    
                    if level.isLocked {
                        // Locked State - Show message to complete previous level
                        VStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            if level.id > 250 && !viewModel.isMilestoneOneComplete {
                                Text("Complete all levels 1-250 first!")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text("You must complete the first 250 levels to unlock the advanced series.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            } else {
                                Text("Complete Level \(level.id - 1) to unlock")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                
                                Text("Levels unlock sequentially as you progress through the game.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    } else if level.isSolved {
                        // Solved -> Show "Play Again" (Restart) logic
                        Button(action: {
                            viewModel.resetLevelProgress(levelID: level.id)
                            onPlay() // Navigate directly without ad
                        }) {
                            Text("Restart Level")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(Color.orange)
                                .cornerRadius(12)
                        }
                    } else {
                        // Unsolved -> Continue/Start
                        Button(action: {
                            onPlay() // Navigate directly without ad
                        }) {
                            Text(level.userProgress == nil ? "Start Level" : "Continue Level")
                                .font(.headline)
                                .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Cancel
                    Button(action: {
                        onCancel()
                    }) {
                        Text("Cancel")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            
        }
    } // Close body
    
    private func formatTime(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
} // Close struct

extension LevelSelectionView {
    // Expose helper static if needed, or duplicate
    static func isSystemIcon(_ name: String) -> Bool {
        // Just a simple check, user requested standard logic.
        // Assuming all logic handles SF vs Assets correctly.
        return true 
    }
}
