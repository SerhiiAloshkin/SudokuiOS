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
    
    @State private var levelID: Int? = nil
    
    var body: some View {
        Group {
            if let id = levelID {
                SudokuGameView(
                    levelID: id,
                    viewModel: viewModel,
                    adCoordinator: adCoordinator
                )
            } else {
                ProgressView("Loading level...")
            }
        }
        .onAppear {
            guard levelID == nil else { return }
            var sudokuLevel = customLevel.toSudokuLevel()
            
            // Hydrate progress from SwiftData
            let id = sudokuLevel.id
            let descriptor = FetchDescriptor<UserLevelProgress>(predicate: #Predicate<UserLevelProgress> { progress in
                progress.levelID == id
            })
            if let progress = try? modelContext.fetch(descriptor).first {
                sudokuLevel.userProgress = progress.currentUserBoard
                sudokuLevel.notesData = progress.notesData
                sudokuLevel.colorData = progress.colorData
                sudokuLevel.markedCombinationsData = progress.markedCombinationsData
                sudokuLevel.killerMarkedCombinationsData = progress.killerMarkedCombinationsData
                sudokuLevel.crossData = progress.crossData
                sudokuLevel.timeElapsed = progress.timeElapsed
                sudokuLevel.bestTime = progress.bestTime
                sudokuLevel.isSolved = progress.isSolved
                sudokuLevel.isPerfect = progress.isPerfect
                sudokuLevel.mistakesMade = progress.mistakesMade
            }
            
            viewModel.injectCustomLevel(sudokuLevel)
            levelID = sudokuLevel.id
            // Store UUID for Continue button on app restart
            UserDefaults.standard.set(customLevel.id.uuidString, forKey: "lastCustomLevelUUID")
        }
    }
}
