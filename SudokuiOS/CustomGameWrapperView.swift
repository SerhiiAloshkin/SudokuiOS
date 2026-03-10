import SwiftUI
import SwiftData

/// Wrapper that converts a CustomSudokuLevel into a standard SudokuLevel
/// and injects it into LevelViewModel so SudokuGameView can play it.
/// CRITICAL: Level injection happens in onAppear (NOT body) to prevent
/// infinite SwiftUI re-render loops from @Published mutations.
@MainActor
struct CustomGameWrapperView: View {
    let customLevel: CustomSudokuLevel
    @ObservedObject var viewModel: LevelViewModel
    @ObservedObject var adCoordinator: AdCoordinator
    @Environment(\.modelContext) private var modelContext
    @Binding var navigationStack: [MainMenuView.SudokuRoute]
    let session: GameSession?
    
    @State private var sudokuLevel: SudokuLevel? = nil
    
    var body: some View {
        Group {
            if let level = sudokuLevel {
                SudokuGameView(
                    level: level,
                    viewModel: viewModel,
                    adCoordinator: adCoordinator,
                    session: session,
                    title: customLevel.levelName
                )
            } else {
                ProgressView("Loading level...")
            }
        }
        .onAppear {
            guard sudokuLevel == nil else { return }
            var level = customLevel.toSudokuLevel()
            
            // Hydrate progress from CustomSudokuLevel directly (SwiftData)
            level.userProgress = customLevel.savedBoardProgress
            level.notesData = customLevel.savedNotesData
            level.colorData = customLevel.savedColorData
            level.markedCombinationsData = customLevel.savedMarkedCombinationsData
            level.killerMarkedCombinationsData = customLevel.savedKillerMarkedCombinationsData
            level.crossData = customLevel.savedCrossData
            level.timeElapsed = customLevel.savedTime
            level.isSolved = customLevel.isSolved
            // Note: mistakesMade and isPerfect are not yet stored on CustomSudokuLevel,
            // but for custom games we primarily care about board state and isSolved.
            
            self.sudokuLevel = level
            // Store UUID for Continue button on app restart
            UserDefaults.standard.set(customLevel.id.uuidString, forKey: "lastCustomLevelUUID")
        }
    }
}
