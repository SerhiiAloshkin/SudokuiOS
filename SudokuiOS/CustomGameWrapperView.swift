import SwiftUI

/// Wrapper that converts a CustomSudokuLevel into a standard SudokuLevel
/// and injects it into LevelViewModel so SudokuGameView can play it.
/// CRITICAL: Level injection happens in onAppear (NOT body) to prevent
/// infinite SwiftUI re-render loops from @Published mutations.
@MainActor
struct CustomGameWrapperView: View {
    let customLevel: CustomSudokuLevel
    @ObservedObject var viewModel: LevelViewModel
    @ObservedObject var adCoordinator: AdCoordinator
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
            let sudokuLevel = customLevel.toSudokuLevel()
            viewModel.injectCustomLevel(sudokuLevel)
            levelID = sudokuLevel.id
            // Store UUID for Continue button on app restart
            UserDefaults.standard.set(customLevel.id.uuidString, forKey: "lastCustomLevelUUID")
        }
    }
}
