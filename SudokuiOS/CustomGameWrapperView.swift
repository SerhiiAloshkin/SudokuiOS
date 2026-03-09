import SwiftUI

/// Wrapper that converts a CustomSudokuLevel into a standard SudokuLevel
/// and injects it into LevelViewModel so SudokuGameView can play it.
@MainActor
struct CustomGameWrapperView: View {
    let customLevel: CustomSudokuLevel
    @ObservedObject var viewModel: LevelViewModel
    @ObservedObject var adCoordinator: AdCoordinator
    @Binding var navigationStack: [MainMenuView.SudokuRoute]
    
    var body: some View {
        let sudokuLevel = customLevel.toSudokuLevel()
        
        // Inject the custom level into the LevelViewModel at a reserved slot
        let _ = viewModel.injectCustomLevel(sudokuLevel)
        
        SudokuGameView(
            levelID: sudokuLevel.id,
            viewModel: viewModel,
            adCoordinator: adCoordinator
        )
    }
}
