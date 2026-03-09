import SwiftUI
import SwiftData

struct LevelBuilderView: View {
    @Binding var navigationStack: [MainMenuView.SudokuRoute]
    @StateObject private var viewModel: LevelBuilderViewModel
    @Environment(\.modelContext) private var modelContext
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)
    @State private var showingAlert = false
    
    // Support both new and edit modes
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
            
            Spacer(minLength: 8)
            
            gridMatrix
            
            Spacer(minLength: 8)
            
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
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { navigationStack.removeLast() }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
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
    
    // MARK: - Multi-Select Global Rules (Req 2)
    
    private var globalRulesToggles: some View {
        HStack(spacing: 8) {
            ForEach(LevelBuilderViewModel.GlobalRule.allCases, id: \.self) { rule in
                ruleToggleButton(rule)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    @ViewBuilder
    private func ruleToggleButton(_ rule: LevelBuilderViewModel.GlobalRule) -> some View {
        let isActive = viewModel.isRuleActive(rule)
        Button(action: { viewModel.toggleRule(rule) }) {
            Text(rule.rawValue)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? Color.blue : Color.clear)
                )
                .foregroundColor(isActive ? .white : .primary)
                .overlay(Capsule().stroke(Color.gray.opacity(0.4), lineWidth: 1))
        }
    }
    
    // MARK: - Tool Palette
    
    private var toolPalette: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
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
                BuilderToolButton(icon: "square.dashed", label: "Cage", isSelected: isCageTool) {
                    viewModel.selectedTool = .cage(10)
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
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Contextual Palette
    
    private var contextualPalette: some View {
        ZStack {
            if isDigitTool { digitPicker }
            else if isCageTool { cageSumPicker }
            else if isOddEvenTool { oddEvenPicker }
            else if viewModel.isShapeInProgress { shapeControls }
        }
        .frame(height: 44)
    }
    
    private var shapeControls: some View {
        HStack(spacing: 16) {
            Button(action: { viewModel.cancelCurrentShape() }) {
                Label("Cancel", systemImage: "xmark")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            
            Button(action: { viewModel.finishCurrentShape() }) {
                Label("Finish Shape", systemImage: "checkmark")
                    .font(.subheadline)
                    .fontWeight(.semibold)
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
                    Label("Validate", systemImage: "checkmark.shield")
                        .font(.subheadline)
                }
            }
            .disabled(viewModel.isValidating)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Grid
    
    private var gridMatrix: some View {
        GeometryReader { geo in
            let availableWidth = max(0, min(geo.size.width, geo.size.height) - 32)
            let cellSize = max(1, availableWidth / 9.0)
            
            ZStack {
                if !viewModel.thermoPaths.isEmpty {
                    ThermoOverlay(paths: viewModel.thermoPaths)
                }
                
                cellsGrid(cellSize: cellSize)
                
                // Kropki dots overlay
                kropkiDotsOverlay(cellSize: cellSize)
                
                // In-progress shape path overlay
                if viewModel.isShapeInProgress {
                    shapePathOverlay(cellSize: cellSize)
                }
            }
            .frame(width: availableWidth, height: availableWidth)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
    
    private func cellsGrid(cellSize: CGFloat) -> some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(viewModel.cells) { cell in
                builderCell(cell: cell, cellSize: cellSize)
                    .onTapGesture {
                        viewModel.handleCellTap(cell.id)
                    }
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
            // Background
            Rectangle()
                .fill(
                    isKropkiSelected ? Color.blue.opacity(0.25) :
                    isInPath ? Color.green.opacity(0.15) :
                    Color.clear
                )
            
            // Parity indicator (Req 3: Odd=Circle, Even=Square)
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
            
            // Cell digit
            if cell.value != 0 {
                Text("\(cell.value)")
                    .font(.system(size: cellSize * 0.55, weight: .bold))
                    .foregroundColor(cell.isClue ? .primary : .blue)
            }
            
            // Shape step number overlay
            if let step = viewModel.stepNumber(for: cell.id) {
                Text("\(step)")
                    .font(.system(size: cellSize * 0.3, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(2)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .border(Color.gray.opacity(0.3), width: 0.5)
        .overlay(blockBoundaryOverlay(for: cell))
    }
    
    @ViewBuilder
    private func blockBoundaryOverlay(for cell: SudokuCellModel) -> some View {
        let col = cell.id % 9
        let row = cell.id / 9
        ZStack {
            if col % 3 == 2 && col != 8 {
                Rectangle()
                    .fill(Color.primary.opacity(0.8))
                    .frame(width: 2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if row % 3 == 2 && row != 8 {
                Rectangle()
                    .fill(Color.primary.opacity(0.8))
                    .frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
    
    // MARK: - Overlays
    
    private func shapePathOverlay(cellSize: CGFloat) -> some View {
        Path { path in
            for (index, cellId) in viewModel.currentShapePath.enumerated() {
                let r = CGFloat(cellId / 9)
                let c = CGFloat(cellId % 9)
                let center = CGPoint(x: c * cellSize + cellSize / 2, y: r * cellSize + cellSize / 2)
                if index == 0 {
                    path.move(to: center)
                } else {
                    path.addLine(to: center)
                }
            }
        }
        .stroke(Color.green.opacity(0.5), style: StrokeStyle(lineWidth: cellSize * 0.3, lineCap: .round, lineJoin: .round))
        .allowsHitTesting(false)
    }
    
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
    
    // MARK: - UI Helpers
    
    var isDigitTool: Bool {
        if case .digit = viewModel.selectedTool { return true }
        return false
    }
    var isCageTool: Bool {
        if case .cage = viewModel.selectedTool { return true }
        return false
    }
    var isOddEvenTool: Bool {
        if case .oddEven = viewModel.selectedTool { return true }
        return false
    }
    var currentDigit: Int {
        if case .digit(let n) = viewModel.selectedTool { return n }
        return 1
    }
    var currentCageSum: Int {
        if case .cage(let s) = viewModel.selectedTool { return s }
        return 10
    }
    var currentParity: String {
        if case .oddEven(let p) = viewModel.selectedTool { return p }
        return "1"
    }
    
    var digitPicker: some View {
        HStack {
            ForEach(1...9, id: \.self) { num in
                Button("\(num)") {
                    viewModel.selectedTool = .digit(num)
                }
                .frame(width: 30, height: 30)
                .background(currentDigit == num ? Color.blue : Color(uiColor: .systemGray5))
                .foregroundColor(currentDigit == num ? .white : .primary)
                .cornerRadius(15)
            }
        }
    }
    
    var cageSumPicker: some View {
        HStack {
            Text("Cage Sum: \(currentCageSum)")
            Stepper("", onIncrement: {
                viewModel.selectedTool = .cage(min(45, currentCageSum + 1))
            }, onDecrement: {
                viewModel.selectedTool = .cage(max(1, currentCageSum - 1))
            })
            .labelsHidden()
        }
    }
    
    var oddEvenPicker: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.selectedTool = .oddEven("1") }) {
                Label("Odd", systemImage: "circle")
                    .font(.subheadline).fontWeight(.medium)
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(currentParity == "1" ? Color.blue : Color(uiColor: .systemGray5))
            .foregroundColor(currentParity == "1" ? .white : .primary)
            .cornerRadius(8)
            
            Button(action: { viewModel.selectedTool = .oddEven("2") }) {
                Label("Even", systemImage: "square")
                    .font(.subheadline).fontWeight(.medium)
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
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .frame(width: 52, height: 52)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(uiColor: .systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(10)
        }
    }
}
