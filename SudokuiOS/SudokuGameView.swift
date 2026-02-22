import SwiftUI
import SwiftData
import Observation

struct SudokuGameView: View {
    @StateObject private var gameViewModel: SudokuGameViewModel
    
    
    
    var onNextLevel: (Int) -> Void = { _ in } // Callback for next level navigation, receives Target ID
    @ObservedObject var adCoordinator: AdCoordinator // Injected for Rewarded Ads
    
    init(levelID: Int, viewModel: LevelViewModel, adCoordinator: AdCoordinator, onNextLevel: @escaping (Int) -> Void = { _ in }) {
        _gameViewModel = StateObject(wrappedValue: SudokuGameViewModel(levelID: levelID, levelViewModel: viewModel))
        self.adCoordinator = adCoordinator
        self.onNextLevel = onNextLevel
    }
    
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) var dismiss // Use dismiss for cleaner syntax
    @Environment(\.scenePhase) var scenePhase
    
    @Environment(AppSettings.self) var settings
    
    @State private var showColorPicker = false
    @State private var showRestartAlert = false

    
    // Gesture State removed (moved to SudokuBoardView)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 8) {
                    // Top Metadata Block
                    SudokuHeaderView(gameViewModel: gameViewModel)
                    
                    // Game Board
                    SudokuBoardView(gameViewModel: gameViewModel)
                    
                    // Spacer to push controls to bottom
                    Spacer(minLength: 12)
                    
                    // Controls Container
                    SudokuControlsView(gameViewModel: gameViewModel, showColorPicker: $showColorPicker)
                    
                    // Bottom Spacer to center controls in lower half
                    Spacer(minLength: 20)
                    
                    // Banner Ad Integration
                    if !settings.didPurchaseRemoveAds {
                        BannerAdView()
                            .frame(height: 50) // Standard Banner Height
                            .padding(.bottom, 0) // Anchor to bottom
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height) // VStack fills screen
                
                // Pause Menu Overlay
                if gameViewModel.isPaused {
                    SudokuPauseOverlayView(gameViewModel: gameViewModel, showRestartAlert: $showRestartAlert)
                }
                
                // Sandwich Helper Overlay
                SudokuSandwichOverlayView(gameViewModel: gameViewModel)
                
                // Victory Overlay
                if gameViewModel.isGameComplete {
                     // Calculate Next Unsolved Level
                     let (nextID, nextVariant) = getNextLevelInfo()
                     
                     VictoryOverlayView(
                        timeElapsed: gameViewModel.formattedTime,
                        currentLevelID: gameViewModel.levelID,
                        nextLevelID: nextID,
                        nextLevelVariant: nextVariant,
                        adCoordinator: adCoordinator, // Pass Coordinator
                        onNextLevel: {
                            // Navigation Only (Ad handled by Overlay)
                            onNextLevel(nextID)
                        },
                        onDismiss: {
                            dismiss()
                        }
                     )
                     .zIndex(200) // Ensure on top of everything
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                gameViewModel.startTimer()
            } else if newPhase == .background || newPhase == .inactive {
                gameViewModel.stopTimer()
            }
        }
        .onAppear {
            gameViewModel.setSettings(settings)
            gameViewModel.startTimer()
        }
        .onDisappear {
            gameViewModel.stopTimer()
        }
        .alert("Restart Level?", isPresented: $showRestartAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restart", role: .destructive) {
                gameViewModel.restartLevel()
                gameViewModel.isPaused = false
            }
        } message: {
            Text("This will clear all your progress.")
        }
        .sheet(isPresented: $gameViewModel.isSettingsPresented) {
            SettingsView(settings: settings)
            //   .presentationDetents([.medium])
        }
        .sheet(isPresented: $gameViewModel.isRulesPresented) {
            RulesView(ruleType: gameViewModel.ruleType ?? .classic, isNegative: gameViewModel.negativeConstraint)
        }
        .navigationTitle("")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .background(SwipeGestureDisabler())

        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                HStack(spacing: 20) {
                    Button(action: {
                        gameViewModel.saveState()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold)) // Match style
                    }
                    
                    Button(action: {
                        gameViewModel.isRulesPresented = true
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 20))
                    }
                }
            }
            ToolbarItem(placement: .principal) {
                Text(gameViewModel.formattedTime)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .monospacedDigit()
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 20) {
                    Button(action: { gameViewModel.isPaused = true }) {
                        Image(systemName: "pause.circle")
                            .font(.system(size: 20)) // Use 20 to match other icons or specific size
                    }
                    Button(action: { gameViewModel.isSettingsPresented = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func getNextLevelInfo() -> (id: Int, variant: SudokuRuleType) {
        let currentID = gameViewModel.levelID
        
        // Gate Logic: If at 250 and milestone not met, redirect to first gap
        if currentID == 250 && !gameViewModel.levelViewModel.isMilestoneOneComplete {
            let firstGapID = gameViewModel.levelViewModel.firstUnsolvedLevelID
            // Attempt to find the variant for this gap level
            let variant = gameViewModel.levelViewModel.levels.first(where: { $0.id == firstGapID })?.ruleType ?? .classic
            return (firstGapID, variant)
        }
        
        // Standard Logic
        let nextLevel = gameViewModel.levelViewModel.findNextUnsolvedLevel(after: currentID)
        let nextID = nextLevel?.id ?? (currentID + 1)
        let variant = nextLevel?.ruleType ?? .classic
        
        return (nextID, variant)
    }
    
    // Gesture methods removed (moved to SudokuBoardView)
    
    // MARK: - Subviews
    
    struct SudokuCellView: View {
        @Bindable var cell: SudokuCellModel
        let highlightType: SudokuGameViewModel.CellHighlightType
        let isError: Bool
        var highlightedDigit: Int? = nil
        var isKiller: Bool = false
        var isNoteHighlightEnabled: Bool = true // New property
        var cellSize: CGFloat
        
        // Wave Effect Props
        var waveOrigin: Int? = nil
        var waveRadius: CGFloat = 0.0
        
        @Environment(\.colorScheme) var colorScheme
        
        // Computed properties to simplify body
        private var baseColor: Color {
            if let userColorIndex = cell.color {
                return SudokuGameViewModel.palette[userColorIndex]
            }
            return Color.clear // Ensure default is transparent to show underlying layers
        }
        
        private var overlayColor: Color? {
            switch highlightType {
            case .selected, .sameValue:
                // Increase opacity by 15% for Light Mode (0.4 -> 0.55)
                return colorScheme == .light ? Color.blue.opacity(0.55) : Color("SelectionHighlight").opacity(0.4)
            case .relating:
                // Increase opacity by 15% for Light Mode (0.35 -> 0.50)
                return Color("RestrictionHighlight").opacity(colorScheme == .light ? 0.50 : 0.35)
            case .none:
                return nil
            }
        }
        
        var body: some View {
            ZStack {
                // 1. Background
                Rectangle()
                    .fill(baseColor)
                
                // 1.5 Note Highlight
                if isNoteHighlightEnabled, cell.value == 0, let digit = highlightedDigit, cell.notes.contains(digit) {
                    Rectangle()
                        .fill(colorScheme == .light ? Color.blue.opacity(0.4) : Color("SelectionHighlight").opacity(0.4))
                }
                
                // 2. Highlight Overlay
                if let overlay = overlayColor {
                    Rectangle()
                        .fill(overlay)
                }
                
                // 3. Content
                if cell.value != 0 {
                    Text("\(cell.value)")
                        .font(.system(size: cellSize * 0.7, weight: isError ? .bold : .medium, design: .rounded))
                        .foregroundColor(cell.isClue ? .primary : (isError ? .red : Color("PlayerNumberColor")))
                } else if !cell.notes.isEmpty {
                    noteGrid
                }
                
                // 3.5 Cross Overlay
                if cell.hasCross {
                    Image(systemName: "multiply")
                        .font(.system(size: cellSize * 0.6, weight: .light))
                        .foregroundColor(.gray.opacity(0.8))
                }
            }
            .overlay(
                Rectangle()
                    .strokeBorder(Color.gray.opacity(0.5), lineWidth: 0.5)
            )
            .aspectRatio(1, contentMode: .fit)
            .clipped()
            .modifier(WaveEffect(index: cell.id, origin: waveOrigin, radius: waveRadius))
            .id("\(cell.id)-\(cell.value)-\(cell.color ?? -1)-\(cell.hasCross)")
        }
        
        // Extracted Note Grid to separate property
        private var noteGrid: some View {
            VStack(spacing: 0) {
                ForEach(0..<3) { r in
                    HStack(spacing: 0) {
                        ForEach(0..<3) { c in
                            let num = r * 3 + c + 1
                            if cell.notes.contains(num) {
                                Text("\(num)")
                                    .font(.system(size: cellSize * 0.25, weight: .regular, design: .rounded))
                                    .minimumScaleFactor(0.5)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    }
                }
            }
            .padding(isKiller ? 8 : 2) // Compact notes to avoid overlapping killer cage values
        }
    }
    
    struct ColorPickerView: View {
        let colors: [Color]
        let onSelect: (Int?) -> Void
        
        var body: some View {
            VStack {
                Text("Select Color")
                    .font(.headline)
                    .padding(.top)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Clear Button
                        Button(action: { onSelect(nil) }) {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "circle.slash")
                                        .resizable()
                                        .padding(8)
                                        .foregroundColor(.red)
                                )
                                .overlay(Circle().stroke(Color.primary, lineWidth: 1))
                        }
                        
                        ForEach(0..<colors.count, id: \.self) { index in
                            Button(action: { onSelect(index) }) {
                                Circle()
                                    .fill(colors[index])
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                            }
                        }
                    }
                    .padding()
                }
            }
            .frame(height: 120)
        }
        
    }
    

    
    // MARK: - Gesture Disabler
    struct SwipeGestureDisabler: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> UIViewController {
            let controller = UIViewController()
            controller.view.backgroundColor = .clear
            return controller
        }
        
        func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
            // Disable gesture in parent navigation controller
            if let navigationController = uiViewController.navigationController {
                navigationController.interactivePopGestureRecognizer?.isEnabled = false
            }
        }
    }
    
    #Preview {
        let container = try! ModelContainer(for: UserLevelProgress.self, MoveHistory.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let levelVM = LevelViewModel(modelContext: container.mainContext)
        levelVM.loadLevelsFromJSON()
        
        return Group {
            SudokuGameView(levelID: 1, viewModel: levelVM, adCoordinator: AdCoordinator())
                .environment(AppSettings())
            
            SudokuGameView(levelID: 1, viewModel: levelVM, adCoordinator: AdCoordinator())
                .environment(AppSettings())
                .preferredColorScheme(.dark)
        }
    }
    
 // End of SudokuGameView
    
    // MARK: - Extracted Subviews
    
    struct SudokuPauseOverlayView: View {
        @ObservedObject var gameViewModel: SudokuGameViewModel
        @Binding var showRestartAlert: Bool
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            ZStack {
                // Dimmed Background
                if #available(iOS 15.0, *) {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Optional: Tap outside to resume
                            // gameViewModel.isPaused = false
                        }
                } else {
                    Color.black.opacity(0.4)
                        .edgesIgnoringSafeArea(.all)
                }
                
                // Card Container
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Paused")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Color("ThemeBlue"))
                        
                        Text("Level \(gameViewModel.levelID) • \(gameViewModel.ruleType?.displayName ?? "Sudoku")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    
                    // Buttons
                    VStack(spacing: 16) {
                        // Continue (Primary)
                        Button(action: {
                            withAnimation {
                                gameViewModel.isPaused = false
                            }
                        }) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color("ThemeBlue"))
                                .cornerRadius(25) // Capsule style
                        }
                        
                        // Reset (Secondary with Alert)
                        Button(action: {
                            showRestartAlert = true
                        }) {
                            Text("Reset Level")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                        
                        // Close (Secondary)
                        Button(action: {
                            gameViewModel.saveState()
                            dismiss()
                        }) {
                            Text("Close Level")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(32)
                .frame(width: 320)
                .background(Color.white)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
                .transition(.scale.combined(with: .opacity))
            }
            .zIndex(200) // Ensure above everything
        }
    }
    
    struct SudokuSandwichOverlayView: View {
        @ObservedObject var gameViewModel: SudokuGameViewModel
        
        var body: some View {
            if let clueInfo = gameViewModel.selectedClue {
                SandwichHelperView(
                    sum: clueInfo.sum,
                    marked: gameViewModel.markedCombinations[clueInfo.id] ?? [],
                    onToggle: { combo in
                        gameViewModel.toggleCombination(combo)
                    },
                    onDismiss: {
                        gameViewModel.dismissSandwichHelper()
                    }
                )
                .zIndex(100)
            }
        }
    }

    struct SudokuHeaderView: View {
        @ObservedObject var gameViewModel: SudokuGameViewModel
        
        var body: some View {
                // Top Metadata Block
                VStack(spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(gameViewModel.levelTitle)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color("ThemeBlue"))
                        
                        // Inline Negative Badge
                        if gameViewModel.negativeConstraint {
                            Text("NEGATIVE")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.15)) // Subtle background
                                .foregroundColor(.red)
                                .cornerRadius(4)
                        }
                    }
                    
                    // Variant Title
                    if let variant = gameViewModel.ruleType?.displayName {
                        Text(variant)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 10)
        }
    }
            
            struct SudokuControlsView: View {
        @ObservedObject var gameViewModel: SudokuGameViewModel
        @Binding var showColorPicker: Bool
        
        var body: some View {
            VStack(spacing: 20) {
                // Tool Bar
                HStack(spacing: 0) {
                    Spacer()
                    
                    // Multi-Select
                    Button(action: { gameViewModel.toggleMultiSelectMode() }) {
                        VStack(spacing: 4) {
                            Image(systemName: gameViewModel.isMultiSelectMode ? "square.on.square.fill" : "square.on.square")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(gameViewModel.isMultiSelectMode ? .purple : .blue)
                            Text("Multi")
                                .font(.caption2)
                                .fixedSize()
                        }
                        .frame(width: 50, height: 50)
                    }
                    
                    Spacer()
                    
                    // Undo
                    Button(action: { gameViewModel.undo() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.backward")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(gameViewModel.canUndo ? .blue : .gray)
                            Text("Undo")
                                .font(.caption2)
                                .fixedSize()
                        }
                        .frame(width: 50, height: 50)
                    }
                    .disabled(!gameViewModel.canUndo)
                    
                    Spacer()
                    
                    // Redo
                    Button(action: { gameViewModel.redo() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.uturn.forward")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(gameViewModel.canRedo ? .blue : .gray)
                            Text("Redo")
                                .font(.caption2)
                                .fixedSize()
                        }
                        .frame(width: 50, height: 50)
                    }
                    .disabled(!gameViewModel.canRedo)
                    
                    Spacer()
                    
                    // Mode Toggle (Notes)
                    Button(action: { gameViewModel.toggleNoteMode() }) {
                        VStack(spacing: 4) {
                            Image(systemName: gameViewModel.isNoteMode ? "pencil.circle.fill" : "pencil.slash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(gameViewModel.isNoteMode ? .orange : .blue)
                            Text(gameViewModel.isNoteMode ? "Notes" : "Enter")
                                .font(.caption2)
                                .fixedSize()
                        }
                        .frame(width: 50, height: 50)
                    }
                    
                    Spacer()
                    
                    // Sandwich Cross Button
                    if gameViewModel.rules.contains(.sandwich) {
                         Button(action: { gameViewModel.toggleCross() }) {
                            VStack(spacing: 4) {
                                Image(systemName: "multiply")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                    .padding(2)
                                    .foregroundColor(.blue)
                                Text("Cross")
                                    .font(.caption2)
                                    .fixedSize()
                            }
                            .frame(width: 50, height: 50)
                        }
                        Spacer()
                    }
                    
                    // Color Picker
                    Button(action: { showColorPicker.toggle() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "paintpalette.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                            Text("Color")
                                .font(.caption2)
                                .fixedSize()
                        }
                        .frame(width: 50, height: 50)
                    }
                    .popover(isPresented: $showColorPicker) {
                        SudokuGameView.ColorPickerView(colors: SudokuGameViewModel.palette) { index in
                            if let index = index {
                                gameViewModel.setCellColor(index)
                            } else {
                                gameViewModel.clearCellColor()
                            }
                            showColorPicker = false
                        }
                        .presentationCompactAdaptation(.popover)
                    }
                    
                    Spacer()
                    
                    // Erase
                    Button(action: { gameViewModel.erase() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "eraser.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                                .foregroundColor(.red)
                            Text("Erase")
                                .font(.caption2)
                                .fixedSize()
                        }
                        .frame(width: 50, height: 50)
                    }
                    
                    Spacer()
                }
                
                // Divider above Number Pad
                Divider()
                    .background(Color.gray.opacity(0.2))
                    .padding(.bottom, 8)
                
                // Number Pad
                NumberPadView { number in
                    gameViewModel.didTapNumber(number)
                }
                .padding(.horizontal, 4) // Matches NumberPadView's calculated margin
                .padding(.bottom, 10) // Bottom padding for home indicator visual space
            }
        }
    }
    
    struct SudokuBoardView: View {
        @ObservedObject var gameViewModel: SudokuGameViewModel
        
        // Grid Config
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)
        
        // Gesture State
        @State private var isDragging = false
        @State private var processedDragIndices: Set<Int> = []
        
        var body: some View {
            GeometryReader { geometry in
                let availableWidth = max(0, geometry.size.width - 16)
                let hasLeftClues = gameViewModel.rowClues != nil
                let hasTopClues = gameViewModel.colClues != nil
                
                let totalCols = CGFloat(hasLeftClues ? 10 : 9)
                let cardPadding: CGFloat = 4
                // Available width must accommodate the columns plus the card padding (horizontal * 2)
                // If left clues exist, they are outside the card, so padding only applies to the 9 grid cols.
                // Width = (1 * cellSize) + (9 * cellSize) + (2 * cardPadding)
                // Width - (2 * cardPadding) = TotalCols * CellSize
                let calculatedCellSize = ((availableWidth - (cardPadding * 2)) / totalCols).rounded(.down)
                let cellSize = max(0, calculatedCellSize)
                let boardSize = cellSize * 9
                
                // Vertical Centering: Use Spacer to push content to center if needed
                // But usually this view is inside a VStack with Spacers. 
                // We'll rely on parent Spacers but ensure local layout is tight.
                
                HStack(alignment: .top, spacing: 0) {
                    // Left Clues (Rows)
                    if let rowClues = gameViewModel.rowClues {
                        VStack(spacing: 0) {
                            if hasTopClues {
                                Color.clear.frame(width: cellSize, height: cellSize)
                                    .padding(.bottom, 4) // Match Top Clues spacing
                            }
                            // Add top padding to align with the grid inside the card
                            Color.clear.frame(height: cardPadding) 
                            
                            ForEach(0..<9, id: \.self) { index in
                                let clue = rowClues[index]
                                if clue >= 0 {
                                    Text("\(clue)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .frame(width: cellSize, height: cellSize)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            gameViewModel.selectClue(index: index, isRow: true, sum: clue)
                                        }
                                } else {
                                    Color.clear.frame(width: cellSize, height: cellSize)
                                }
                            }
                            
                            // Bottom padding to align with grid inside card
                            Color.clear.frame(height: cardPadding)
                        }
                        .padding(.trailing, 2) // Slight gap between clues and card
                    }
                    
                    // Main Content (Top Clues + Board)
                    VStack(spacing: 0) {
                        // Top Clues (Columns)
                        if let colClues = gameViewModel.colClues {
                            HStack(spacing: 0) {
                                ForEach(0..<9, id: \.self) { index in
                                    let clue = colClues[index]
                                    if clue >= 0 {
                                        Text("\(clue)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .frame(width: cellSize, height: cellSize)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                gameViewModel.selectClue(index: index, isRow: false, sum: clue)
                                            }
                                    } else {
                                        Color.clear.frame(width: cellSize, height: cellSize)
                                    }
                                }
                            }
                            .padding(.horizontal, cardPadding) // Align with grid columns inside card
                            .padding(.bottom, 4) // Gap between clues and card
                        }
                        
                        // The Grid Card
                        ZStack {
                            Color(UIColor.systemBackground) // Grid background
                            
                            // OddEvenLayer moved to .overlay below to ensure it renders ON TOP of cell selection fills
                            
                            if let arrows = gameViewModel.arrows {
                                ArrowDrawingView(arrows: arrows)
                            }
                            
                            LazyVGrid(columns: columns, spacing: 0) {
                                ForEach(gameViewModel.cells) { cell in
                                    SudokuGameView.SudokuCellView(
                                        cell: cell,
                                        highlightType: gameViewModel.getHighlightType(at: cell.id),
                                        isError: gameViewModel.shouldShowMistake(at: cell.id),
                                        highlightedDigit: gameViewModel.selectedDigit,
                                        isKiller: gameViewModel.cages != nil,
                                        isNoteHighlightEnabled: gameViewModel.settings?.isHighlightSameNoteEnabled ?? true,
                                        cellSize: cellSize,
                                        waveOrigin: gameViewModel.waveOrigin,
                                        waveRadius: gameViewModel.waveRadius
                                    )
                                    .frame(height: cellSize)
                                }
                            }
                            .id(gameViewModel.boardID)
                            
                            if let cages = gameViewModel.cages {
                                KillerCageLayer(cages: cages)
                            }
                        }
                        .overlay(
                            Group {
                                if let parity = gameViewModel.parityOverlay {
                                    OddEvenLayer(parityString: parity, cellSize: cellSize)
                                }
                            }
                        )
                        .overlay(ThermoOverlay(paths: gameViewModel.thermoPaths))
                        .overlay(SudokuBoardOverlay())
                        .overlay(
                            Group {
                                if (gameViewModel.whiteDots != nil || gameViewModel.blackDots != nil) {
                                    KropkiLayer(
                                        whiteDots: gameViewModel.whiteDots ?? [],
                                        blackDots: gameViewModel.blackDots ?? [],
                                        errorBorders: gameViewModel.kropkiErrors,
                                        backgroundColor: Color(uiColor: .systemBackground)
                                    )
                                }
                            }
                        )
                        .clipped()
                        // Restore Border: Primary color, 2pt width
                        .border(Color.primary, width: 2)
                        .frame(width: boardSize, height: boardSize)
                        .coordinateSpace(name: "board")
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDragChanged(value, boardSize: boardSize)
                                }
                                .onEnded { value in
                                    handleDragEnded(value, boardSize: boardSize)
                                }
                        )
                        // Card Styling
                        .padding(cardPadding) // Internal padding
                        .background(Color.white) // Card background
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 20)
                .frame(width: geometry.size.width)
            }
        }
        
        private func handleDragChanged(_ value: DragGesture.Value, boardSize: CGFloat) {
            let location = value.location
            let cellSize = boardSize / 9.0
            
            let col = Int(location.x / cellSize)
            let row = Int(location.y / cellSize)
            
            if col >= 0 && col < 9 && row >= 0 && row < 9 {
                let index = row * 9 + col
                
                // Gesture Start Detection
                let isStart = !isDragging
                if isStart {
                    isDragging = true
                    processedDragIndices.removeAll()
                    
                    // Handle Initial Selection State (Clear if Single Mode & Outside)
                    gameViewModel.gestureStart(at: index)
                }
                
                // Once-per-Gesture Constraint
                if !processedDragIndices.contains(index) {
                    processedDragIndices.insert(index)
                    
                    // Perform Toggle (Visual & Logical)
                    gameViewModel.dragToggle(index)
                }
            }
        }
        
        private func handleDragEnded(_ value: DragGesture.Value, boardSize: CGFloat) {
            isDragging = false
            processedDragIndices.removeAll()
        }
    }
}

struct WaveEffect: ViewModifier {
    let index: Int
    let origin: Int?
    let radius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        if let origin = origin {
            let r = index / 9
            let c = index % 9
            let or = origin / 9
            let oc = origin % 9
            
            let distance = sqrt(pow(CGFloat(r - or), 2) + pow(CGFloat(c - oc), 2))
            let diff = distance - radius
            
            // Effect Window: -1.5 to 0.5 (Wavefront thickness)
            if diff < 0.5 && diff > -1.5 {
                // Wave is passing
                let intensity = 1.0 - abs(diff + 0.5) // Peak at -0.5
                
                // Color Selection
                // Dark Mode: Cyan/Blue mix for neon look
                // Light Mode: Clearer Blue/Cyan
                let waveColor = colorScheme == .dark ? Color.cyan : Color.blue
                
                return AnyView(content
                    .scaleEffect(1.0 + (0.15 * intensity))
                    .overlay(
                        waveColor
                            .opacity(0.3 * intensity)
                            .allowsHitTesting(false)
                    )
                )
            }
        }
        return AnyView(content)
    }
}
