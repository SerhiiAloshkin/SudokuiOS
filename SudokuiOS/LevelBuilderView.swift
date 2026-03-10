import SwiftUI
import SwiftData

struct LevelBuilderView: View {
    @Binding var navigationStack: [MainMenuView.SudokuRoute]
    @StateObject private var viewModel: LevelBuilderViewModel
    @Environment(\.modelContext) private var modelContext
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)
    @State private var showingAlert = false
    
    init(navigationStack: Binding<[MainMenuView.SudokuRoute]>, existingLevel: CustomSudokuLevel? = nil) {
        _navigationStack = navigationStack
        if let level = existingLevel {
            _viewModel = StateObject(wrappedValue: LevelBuilderViewModel(existingLevel: level))
        } else {
            _viewModel = StateObject(wrappedValue: LevelBuilderViewModel())
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            globalRulesToggles
            toolPalette
            contextualPalette
            Spacer(minLength: 4)
            gridMatrix
            Spacer(minLength: 4)
            bottomControls
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel.validationResult) { _, result in
            if result != nil { showingAlert = true }
        }
        .alert("Status", isPresented: $showingAlert, presenting: viewModel.validationResult) { _ in
            Button("OK") {
                if viewModel.validationResult == "Saved successfully!" {
                    navigationStack.removeLast()
                }
                viewModel.validationResult = nil
            }
        } message: { result in
            Text(result)
        }
        .sensoryFeedback(.warning, trigger: viewModel.showInvalidTapFeedback)
        .alert("Cage Sum", isPresented: $viewModel.showCageSumPrompt) {
            TextField("Enter sum", text: $viewModel.pendingCageSum)
                .keyboardType(.numberPad)
            Button("OK") { viewModel.commitCageWithSum() }
            Button("Cancel", role: .cancel) { viewModel.cancelCurrentShape() }
        } message: {
            Text("Enter the target sum for this killer cage.")
        }
        .alert("Name Your Level", isPresented: $viewModel.showSaveNamePrompt) {
            TextField("Level name", text: $viewModel.pendingLevelName)
            Button("Save") { viewModel.commitSave(context: modelContext) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a name, or leave blank for an auto-generated name.")
        }
        .alert("Sandwich Clue", isPresented: $viewModel.showSandwichAlert) {
            TextField("Sum (0 or 2-35)", text: $viewModel.sandwichInputValue)
                .keyboardType(.numberPad)
            Button("Save") { viewModel.commitSandwichClue() }
                .disabled(!viewModel.isSandwichInputValid)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter the sum of digits between 1 and 9 for this \(viewModel.isRowSandwich ? "row" : "column").\nValid values: 0 (adjacent) or 2-35.")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { navigationStack.removeLast() }) {
                Image(systemName: "chevron.left")
                    .font(.title2).foregroundColor(.primary)
            }
            Spacer()
            Text("Level Builder").font(.headline)
            Spacer()
            Button(action: { viewModel.saveLevel(context: modelContext) }) {
                Text("Save").fontWeight(.bold)
            }
        }
        .padding()
    }
    
    // MARK: - Multi-Select Global Rules
    
    private var globalRulesToggles: some View {
        HStack(spacing: 8) {
            ForEach(LevelBuilderViewModel.GlobalRule.allCases, id: \.self) { rule in
                ruleToggleButton(rule)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }
    
    @ViewBuilder
    private func ruleToggleButton(_ rule: LevelBuilderViewModel.GlobalRule) -> some View {
        let isActive = viewModel.isRuleActive(rule)
        Button(action: { viewModel.toggleRule(rule) }) {
            Text(rule.rawValue)
                .font(.caption).fontWeight(.semibold)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(isActive ? Color.blue : Color.clear))
                .foregroundColor(isActive ? .white : .primary)
                .overlay(Capsule().stroke(Color.gray.opacity(0.4), lineWidth: 1))
        }
    }
    
    // MARK: - Tool Palette
    
    private var toolPalette: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 12) {
                BuilderToolButton(icon: "eraser", label: "Erase", isSelected: viewModel.selectedTool == .erase) {
                    viewModel.selectedTool = .erase
                }
                BuilderToolButton(icon: "number.circle", label: "Digit", isSelected: isDigitTool) {
                    viewModel.selectedTool = .digit(1)
                }
                BuilderToolButton(icon: "thermometer", label: "Thermo", isSelected: viewModel.selectedTool == .thermo) {
                    viewModel.selectedTool = .thermo
                }
                BuilderToolButton(icon: "arrow.up.right", label: "Arrow", isSelected: viewModel.selectedTool == .arrow) {
                    viewModel.selectedTool = .arrow
                }
                BuilderToolButton(icon: "square.dashed", label: "Cage", isSelected: viewModel.selectedTool == .cage) {
                    viewModel.selectedTool = .cage
                }
                BuilderToolButton(icon: "circle.square", label: "Odd/Even", isSelected: isOddEvenTool) {
                    viewModel.selectedTool = .oddEven("1")
                }
                BuilderToolButton(icon: "circle", label: "W. Dot", isSelected: viewModel.selectedTool == .whiteDot) {
                    viewModel.selectedTool = .whiteDot
                }
                BuilderToolButton(icon: "circle.fill", label: "B. Dot", isSelected: viewModel.selectedTool == .blackDot) {
                    viewModel.selectedTool = .blackDot
                }
                // Placeholder to ensure the last item can be fully seen even with the mask
                Spacer().frame(width: 20)
            }
            .padding(.horizontal)
        }
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.85),
                    .init(color: .clear, location: 1)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .padding(.vertical, 6)
    }
    
    // MARK: - Contextual Palette
    
    private var contextualPalette: some View {
        ZStack {
            if isDigitTool { digitPicker }
            else if isOddEvenTool { oddEvenPicker }
            else if viewModel.isShapeInProgress { shapeControls }
        }
        .frame(height: 44)
    }
    
    private var shapeControls: some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.cancelCurrentShape() }) {
                Label("Cancel", systemImage: "xmark").font(.subheadline)
            }
            .buttonStyle(.bordered).tint(.red)
            
            Button(action: { viewModel.finishCurrentShape() }) {
                Label("Finish Shape", systemImage: "checkmark")
                    .font(.subheadline).fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.currentShapePath.count < 2)
        }
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.checkValidation() }) {
                if viewModel.isValidating {
                    ProgressView().frame(height: 20)
                } else {
                    Label("Validate", systemImage: "checkmark.shield").font(.subheadline)
                }
            }
            .disabled(viewModel.isValidating)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal).padding(.bottom, 8)
    }
    
    // MARK: - Grid Matrix
    
    private var gridMatrix: some View {
        GeometryReader { geo in
            let cardPadding: CGFloat = 4
            // Accommodation for exterior clues: 1 cell width + small gap
            let totalCols: CGFloat = 10 
            let calculatedCellSize = ((geo.size.width - 32 - (cardPadding * 2)) / totalCols).rounded(.down)
            let cellSize = max(1, calculatedCellSize)
            let boardSize = cellSize * 9
            
            HStack(alignment: .top, spacing: 0) {
                // Left Clues (Rows)
                VStack(spacing: 0) {
                    // Spacer for Top Clues alignment
                    Color.clear.frame(width: cellSize, height: cellSize)
                        .padding(.bottom, 8) 
                    
                    // Match card internal padding
                    Color.clear.frame(height: cardPadding) 
                    
                    ForEach(0..<9, id: \.self) { i in
                        sandwichClueButton(index: i, isRow: true, cellSize: cellSize)
                    }
                }
                .padding(.trailing, 4)
                
                VStack(spacing: 0) {
                    // Top Clues (Columns)
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { i in
                            sandwichClueButton(index: i, isRow: false, cellSize: cellSize)
                        }
                    }
                    .padding(.bottom, 8)
                    
                    // The Grid Card
                    ZStack {
                        Color(UIColor.systemBackground)
                        
                        // Layer 1: Cell grid
                        cellsGrid(cellSize: cellSize)
                        
                        // Layer 2: Finalized shapes
                        finalizedShapesOverlay(cellSize: cellSize)
                        
                        // Layer 3: In-progress shape
                        if viewModel.isShapeInProgress {
                            activeShapeOverlay(cellSize: cellSize)
                        }
                        
                        // Layer 4: Kropki dots
                        kropkiDotsOverlay(cellSize: cellSize)
                        
                        // Layer 5: Step numbers
                        if viewModel.isShapeInProgress {
                            stepNumbersOverlay(cellSize: cellSize)
                        }
                    }
                    .frame(width: boardSize, height: boardSize)
                    .padding(cardPadding)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 2)
                }
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
    
    @ViewBuilder
    private func sandwichClueButton(index: Int, isRow: Bool, cellSize: CGFloat) -> some View {
        let clue = isRow ? viewModel.sandwichRowClues[index] : viewModel.sandwichColClues[index]
        let isEraser = viewModel.selectedTool == .erase
        let hasClue = clue != nil
        
        Button(action: { viewModel.handleSandwichTap(index: index, isRow: isRow) }) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(hasClue ? Color.blue.opacity(0.1) : Color.gray.opacity(0.05))
                    .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                
                Text(hasClue ? "\(clue!)" : "-")
                    .font(.system(size: cellSize * 0.4, weight: .bold, design: .rounded))
                    .foregroundColor(hasClue ? .blue : .secondary.opacity(0.3))
            }
        }
        .frame(width: cellSize, height: cellSize)
    }
    
    // MARK: - Cells Grid (Fix 1: contentShape for reliable hit testing)
    
    private func cellsGrid(cellSize: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(viewModel.cells) { cell in
                builderCell(cell: cell, cellSize: cellSize)
            }
        }
        .border(Color.primary, width: 2)
        .background(Color(uiColor: .systemBackground))
    }
    
    @ViewBuilder
    private func builderCell(cell: SudokuCellModel, cellSize: CGFloat) -> some View {
        let isInPath = viewModel.currentShapePath.contains(cell.id)
        let isKropkiSelected = viewModel.kropkiFirstCell == cell.id
        
        ZStack {
            // Background highlight
            Rectangle().fill(
                isKropkiSelected ? Color.blue.opacity(0.25) :
                isInPath ? Color.green.opacity(0.15) :
                Color.clear
            )
            
            // Parity visual (Odd=Circle, Even=Square)
            parityOverlay(for: cell, cellSize: cellSize)
            
            // Digit
            if cell.value != 0 {
                Text("\(cell.value)")
                    .font(.system(size: cellSize * 0.55, weight: .bold))
                    .foregroundColor(cell.isClue ? .primary : .blue)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .contentShape(Rectangle()) // FIX 1: Ensures empty cells register taps
        .onTapGesture { viewModel.handleCellTap(cell.id) }
        .border(Color.gray.opacity(0.3), width: 0.5)
        .overlay(blockBoundaryOverlay(for: cell))
    }
    
    @ViewBuilder
    private func parityOverlay(for cell: SudokuCellModel, cellSize: CGFloat) -> some View {
        if let p = cell.parity {
            if p == "1" {
                Circle()
                    .stroke(Color.oddEvenFrame, lineWidth: 2)
                    .padding(cellSize * 0.125)
            } else if p == "2" {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.oddEvenFrame, lineWidth: 2)
                    .padding(cellSize * 0.125)
            }
        }
    }
    
    @ViewBuilder
    private func blockBoundaryOverlay(for cell: SudokuCellModel) -> some View {
        let col = cell.id % 9
        let row = cell.id / 9
        ZStack {
            if col % 3 == 2 && col != 8 {
                Rectangle().fill(Color.primary.opacity(0.8))
                    .frame(width: 2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if row % 3 == 2 && row != 8 {
                Rectangle().fill(Color.primary.opacity(0.8))
                    .frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
    
    // MARK: - Fix 2 & 3: Shape Overlays
    
    /// Finalized committed shapes — uses exact same components as the actual game
    @ViewBuilder
    private func finalizedShapesOverlay(cellSize: CGFloat) -> some View {
        let gridSize = cellSize * 9
        
        // Thermos (same as SudokuGameView)
        if !viewModel.thermoPaths.isEmpty {
            ThermoOverlay(paths: viewModel.thermoPaths)
                .frame(width: gridSize, height: gridSize)
                .allowsHitTesting(false)
        }
        
        // Arrows (same as SudokuGameView)
        if !viewModel.arrows.isEmpty {
            ArrowDrawingView(arrows: viewModel.arrows)
                .frame(width: gridSize, height: gridSize)
                .allowsHitTesting(false)
        }
        
        // Killer Cages (same as SudokuGameView)
        if !viewModel.cages.isEmpty {
            KillerCageLayer(cages: viewModel.cages)
                .frame(width: gridSize, height: gridSize)
                .allowsHitTesting(false)
        }
    }
    
    /// Active in-progress shape — renders head + body in real-time as user taps
    @ViewBuilder
    private func activeShapeOverlay(cellSize: CGFloat) -> some View {
        let path = viewModel.currentShapePath
        let gridSize = cellSize * 9
        
        switch viewModel.selectedTool {
        case .thermo:
            // Real-time thermo: gray line + circle bulb at head
            activeThermo(path: path, cellSize: cellSize)
                .frame(width: gridSize, height: gridSize)
                .allowsHitTesting(false)
        case .arrow:
            // Real-time arrow: circle at head + line body
            activeArrow(path: path, cellSize: cellSize)
                .frame(width: gridSize, height: gridSize)
                .allowsHitTesting(false)
        case .cage:
            // Real-time cage: dashed outline
            activeCage(path: path, cellSize: cellSize)
                .frame(width: gridSize, height: gridSize)
                .allowsHitTesting(false)
        default:
            EmptyView()
        }
    }
    
    // Active Thermo: matches ThermoOverlay style
    private func activeThermo(path: [Int], cellSize: CGFloat) -> some View {
        ZStack {
            // Line
            Path { p in
                for (i, cellId) in path.enumerated() {
                    let center = cellCenter(cellId, cellSize: cellSize)
                    if i == 0 { p.move(to: center) }
                    else { p.addLine(to: center) }
                }
            }
            .stroke(Color.gray, style: StrokeStyle(lineWidth: cellSize * 0.35, lineCap: .round, lineJoin: .round))
            
            // Bulb at head
            if let first = path.first {
                let c = cellCenter(first, cellSize: cellSize)
                Circle()
                    .fill(Color.gray)
                    .frame(width: cellSize * 0.85, height: cellSize * 0.85)
                    .position(x: c.x, y: c.y)
            }
        }
        .compositingGroup()
        .opacity(0.4)
    }
    
    // Active Arrow: uses the REAL ArrowDrawingView for accurate rendering
    @ViewBuilder
    private func activeArrow(path: [Int], cellSize: CGFloat) -> some View {
        if path.count >= 2 {
            let bulb = [path[0] / 9, path[0] % 9]
            let line = path.dropFirst().map { [$0 / 9, $0 % 9] }
            let tempArrow = SudokuLevel.Arrow(bulb: bulb, line: line)
            ArrowDrawingView(arrows: [tempArrow])
        } else if let first = path.first {
            // Only head placed — just show the circle
            let c = cellCenter(first, cellSize: cellSize)
            Circle()
                .stroke(Color.gray, lineWidth: 2)
                .frame(width: cellSize * 0.8, height: cellSize * 0.8)
                .position(x: c.x, y: c.y)
                .compositingGroup()
                .opacity(0.4)
        }
    }
    
    // Active Cage: dashed outline around selected cells
    private func activeCage(path: [Int], cellSize: CGFloat) -> some View {
        ZStack {
            ForEach(path, id: \.self) { cellId in
                let row = cellId / 9
                let col = cellId % 9
                Rectangle()
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    .frame(width: cellSize, height: cellSize)
                    .position(
                        x: CGFloat(col) * cellSize + cellSize / 2,
                        y: CGFloat(row) * cellSize + cellSize / 2
                    )
            }
        }
    }
    
    // Step numbers overlaid on active shape cells
    private func stepNumbersOverlay(cellSize: CGFloat) -> some View {
        ZStack {
            ForEach(Array(viewModel.currentShapePath.enumerated()), id: \.element) { index, cellId in
                let c = cellCenter(cellId, cellSize: cellSize)
                Text("\(index + 1)")
                    .font(.system(size: cellSize * 0.28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Circle().fill(Color.green.opacity(0.85)))
                    .position(x: c.x - cellSize * 0.3, y: c.y - cellSize * 0.3)
            }
        }
        .allowsHitTesting(false)
    }
    
    // Kropki dots on cell borders
    private func kropkiDotsOverlay(cellSize: CGFloat) -> some View {
        ZStack {
            ForEach(Array(viewModel.whiteDots.enumerated()), id: \.offset) { _, dot in
                kropkiDotView(dot: dot, cellSize: cellSize, isFilled: false)
            }
            ForEach(Array(viewModel.blackDots.enumerated()), id: \.offset) { _, dot in
                kropkiDotView(dot: dot, cellSize: cellSize, isFilled: true)
            }
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private func kropkiDotView(dot: SudokuLevel.KropkiDot, cellSize: CGFloat, isFilled: Bool) -> some View {
        let x = CGFloat(dot.c1 + dot.c2) / 2.0 * cellSize + cellSize / 2
        let y = CGFloat(dot.r1 + dot.r2) / 2.0 * cellSize + cellSize / 2
        let dotSize = cellSize * 0.25
        Circle()
            .fill(isFilled ? Color.primary : Color(uiColor: .systemBackground))
            .frame(width: dotSize, height: dotSize)
            .overlay(Circle().stroke(Color.primary, lineWidth: 1.5))
            .position(x: x, y: y)
    }
    
    // MARK: - Helpers
    
    private func cellCenter(_ cellId: Int, cellSize: CGFloat) -> CGPoint {
        let row = cellId / 9
        let col = cellId % 9
        return CGPoint(
            x: CGFloat(col) * cellSize + cellSize / 2,
            y: CGFloat(row) * cellSize + cellSize / 2
        )
    }
    
    var isDigitTool: Bool {
        if case .digit = viewModel.selectedTool { return true }; return false
    }
    var isCageTool: Bool { viewModel.selectedTool == .cage }
    var isOddEvenTool: Bool {
        if case .oddEven = viewModel.selectedTool { return true }; return false
    }
    var currentDigit: Int {
        if case .digit(let n) = viewModel.selectedTool { return n }; return 1
    }
    var currentCageSum: Int { return 10 }
    var currentParity: String {
        if case .oddEven(let p) = viewModel.selectedTool { return p }; return "1"
    }
    
    var digitPicker: some View {
        HStack {
            ForEach(1...9, id: \.self) { num in
                Button("\(num)") { viewModel.selectedTool = .digit(num) }
                    .frame(width: 30, height: 30)
                    .background(currentDigit == num ? Color.blue : Color(uiColor: .systemGray5))
                    .foregroundColor(currentDigit == num ? .white : .primary)
                    .cornerRadius(15)
            }
        }
    }
    

    
    var oddEvenPicker: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.selectedTool = .oddEven("1") }) {
                Label("Odd", systemImage: "circle").font(.subheadline).fontWeight(.medium)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(currentParity == "1" ? Color.blue : Color(uiColor: .systemGray5))
            .foregroundColor(currentParity == "1" ? .white : .primary)
            .cornerRadius(8)
            
            Button(action: { viewModel.selectedTool = .oddEven("2") }) {
                Label("Even", systemImage: "square").font(.subheadline).fontWeight(.medium)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(currentParity == "2" ? Color.orange : Color(uiColor: .systemGray5))
            .foregroundColor(currentParity == "2" ? .white : .primary)
            .cornerRadius(8)
        }
    }
}

// MARK: - Supporting Views

struct BuilderToolButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(label).font(.system(size: 9, weight: .medium))
            }
            .frame(width: 52, height: 52)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(uiColor: .systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(10)
        }
    }
}
