import SwiftUI

struct LevelPreviewModal: View {
    let level: SudokuLevel
    @ObservedObject var viewModel: LevelViewModel // To call reset
    @ObservedObject var adCoordinator: AdCoordinator // Ad Manager
    
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
                    
                    // Variant Label with Icon
                    HStack {
                        if level.ruleType == .knight {
                           Image("knight_icon")
                               .resizable()
                               .renderingMode(.template) 
                               .scaledToFit()
                               .frame(width: 16, height: 16)
                        } else if !LevelSelectionView.isSystemIcon(level.ruleType.iconName) {
                            // Assuming SF Symbol if part of enum, logic copied from Card View mostly
                            Image(systemName: level.ruleType.iconName)
                        }
                        Text(level.ruleType.displayName)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
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
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Solved: \(formatTime(seconds: level.timeElapsed))")
                            .fontWeight(.semibold)
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
                        // Locked State
                        if level.id <= 250 {
                            // Ad Unlockable
                            Button(action: {
                                adCoordinator.showRewardedVideo { success in
                                    if success {
                                        // Ad dismissed/completed -> Grant Unlock
                                        viewModel.unlockLevelViaAd(level.id)
                                        onPlay() // Proceed to game
                                    } else {
                                        // Failed
                                        print("Ad failed or cancelled")
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "play.rectangle.fill") // SF Symbol
                                    Text("Unlock with Ad")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(Color.blue) // Match Continue Level color
                                .cornerRadius(12)
                            }
                        } else {
                            // Barrier Locked (Levels > 250)
                            if !viewModel.isMilestoneOneComplete {
                                Text("Complete all previous 250 levels to unlock this challenge!")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(12)
                            } else {
                                Text("Complete Previous Level or Watch Ad") // Fallback / Should trigger Ad Logic if allowed
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    } else if level.isSolved {
                        // Solved -> Show "Play Again" (Restart) logic
                        Button(action: {
                            viewModel.resetLevelProgress(levelID: level.id)
                            onPlay() // Navigate to fresh game
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
                            onPlay()
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
