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
    
    @State private var sudokuLevel: SudokuLevel? = nil
    
    var body: some View {
        Group {
            if let level = sudokuLevel {
                SudokuGameView(
                    level: level,
                    viewModel: viewModel,
                    adCoordinator: adCoordinator
                )
            } else {
                ProgressView("Loading level...")
            }
        }
        .onAppear {
            guard sudokuLevel == nil else { return }
            var level = customLevel.toSudokuLevel()
            
            // Hydrate progress from SwiftData
            let id = level.id
            let descriptor = FetchDescriptor<UserLevelProgress>(predicate: #Predicate<UserLevelProgress> { progress in
                progress.levelID == id
            })
            if let progress = try? modelContext.fetch(descriptor).first {
                level.userProgress = progress.currentUserBoard
                level.notesData = progress.notesData
                level.colorData = progress.colorData
                level.markedCombinationsData = progress.markedCombinationsData
                level.killerMarkedCombinationsData = progress.killerMarkedCombinationsData
                level.crossData = progress.crossData
                level.timeElapsed = progress.timeElapsed
                level.bestTime = progress.bestTime
                level.isSolved = progress.isSolved
                level.isPerfect = progress.isPerfect
                level.mistakesMade = progress.mistakesMade
            }
            
            self.sudokuLevel = level
            // Store UUID for Continue button on app restart
            UserDefaults.standard.set(customLevel.id.uuidString, forKey: "lastCustomLevelUUID")
        }
    }
}
