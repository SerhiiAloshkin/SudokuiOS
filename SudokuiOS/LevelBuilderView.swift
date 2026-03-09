import SwiftUI
import SwiftData

struct LevelBuilderView: View {
    @Binding var navigationStack: [MainMenuView.SudokuRoute]
    @StateObject private var viewModel = LevelBuilderViewModel()
    @Environment(\.modelContext) private var modelContext
    
    // Grid Setup
    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)
    @State private var showingAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: {
                    navigationStack.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Level Builder")
                    .font(.headline)
                
                Spacer()
                Button(action: {
                    viewModel.validateAndSave(context: modelContext)
                }) {
                    if viewModel.isValidating {
                        ProgressView()
                    } else {
                        Text("Save")
                            .fontWeight(.bold)
                    }
                }
                .disabled(viewModel.isValidating)
            }
            .padding()
            
            // Tool Palette (Horizontal Scroll)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    BuilderToolButton(icon: "eraser", label: "Erase", isSelected: viewModel.selectedTool == .erase) {
                        viewModel.selectedTool = .erase
                    }
                    
                    BuilderToolButton(icon: "number.circle", label: "Digit", isSelected: isDigitTool) {
                        viewModel.selectedTool = .digit(1) // Default to 1
                    }
                    
                    BuilderToolButton(icon: "thermometer", label: "Thermo", isSelected: viewModel.selectedTool == .thermo) {
                        viewModel.selectedTool = .thermo
                    }
                    
                    BuilderToolButton(icon: "arrow.up.right", label: "Arrow", isSelected: viewModel.selectedTool == .arrow) {
                        viewModel.selectedTool = .arrow
                    }
                    
                    BuilderToolButton(icon: "square.dashed", label: "Cage", isSelected: isCageTool) {
                        viewModel.selectedTool = .cage(10) // Default sum
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 10)
            
            // Contextual Palette options
            if isDigitTool {
                digitPicker
            } else if isCageTool {
                cageSumPicker
            }
            
            Spacer()
            
            // The Grid Matrix
            GeometryReader { geo in
                let availableWidth = min(geo.size.width, geo.size.height) - 32
                let cellSize = availableWidth / 9.0
                
                ZStack {
                    // Lines and Cages Layer
                    if !viewModel.thermoPaths.isEmpty { ThermoOverlay(paths: viewModel.thermoPaths) }
                    // TODO: Add Arrow/Cage Drawing
                    if viewModel.isDrawing {
                        // Temp drawing path rendering
                        Path { path in
                            for (index, cellId) in viewModel.currentDrawingPath.enumerated() {
                                let r = CGFloat(cellId / 9)
                                let c = CGFloat(cellId % 9)
                                let center = CGPoint(x: c * cellSize + cellSize/2, y: r * cellSize + cellSize/2)
                                if index == 0 {
                                    path.move(to: center)
                                } else {
                                    path.addLine(to: center)
                                }
                            }
                        }
                        .stroke(Color.blue.opacity(0.5), lineWidth: cellSize * 0.4)
                    }
                    
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(viewModel.cells) { cell in
                            BuilderCellView(cell: cell, cellSize: cellSize, isSelected: false)
                                .frame(width: cellSize, height: cellSize)
                                .border(Color.gray.opacity(0.5), width: 0.5)
                        }
                    }
                    .border(Color.primary, width: 2)
                    .background(Color.white)
                    
                    // Invisible Drag/Tap layer for entire board
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let col = Int(value.location.x / cellSize)
                                    let row = Int(value.location.y / cellSize)
                                    if col >= 0 && col < 9 && row >= 0 && row < 9 {
                                        let cellId = row * 9 + col
                                        if viewModel.isDrawing {
                                            viewModel.updateDrawing(to: cellId)
                                        } else {
                                            viewModel.handleCellTap(cellId) // Tap fallback
                                            if viewModel.requiresDragToDraw {
                                                 viewModel.startDrawing(at: cellId)
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    viewModel.endDrawing()
                                }
                        )
                }
                .frame(width: availableWidth, height: availableWidth)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel.validationResult) { _, result in
            if result != nil {
                showingAlert = true
            }
        }
        .alert("Validation", isPresented: $showingAlert, presenting: viewModel.validationResult) { _ in
            Button("OK") {
                if viewModel.validationResult == "Saved successfully!" {
                    navigationStack.removeLast()
                }
                viewModel.validationResult = nil
            }
        } message: { result in
            Text(result)
        }
    }
    
    // UI Helpers
    var isDigitTool: Bool {
        if case .digit = viewModel.selectedTool { return true }
        return false
    }
    
    var isCageTool: Bool {
        if case .cage = viewModel.selectedTool { return true }
        return false
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
        .padding(.bottom, 10)
    }
    
    var cageSumPicker: some View {
        // Simple stepper for cage sum
        HStack {
            Text("Cage Sum: \(currentCageSum)")
            Stepper("", onIncrement: {
                viewModel.selectedTool = .cage(min(45, currentCageSum + 1))
            }, onDecrement: {
                viewModel.selectedTool = .cage(max(1, currentCageSum - 1))
            })
            .labelsHidden()
        }
        .padding(.bottom, 10)
    }
    
    var currentDigit: Int {
        if case .digit(let n) = viewModel.selectedTool { return n }
        return 1
    }
    
    var currentCageSum: Int {
        if case .cage(let s) = viewModel.selectedTool { return s }
        return 10
    }
}

struct BuilderToolButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 60, height: 60)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(uiColor: .systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(12)
        }
    }
}

struct BuilderCellView: View {
    let cell: SudokuCellModel
    let cellSize: CGFloat
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            if cell.value != 0 {
                Text("\(cell.value)")
                    .font(.system(size: cellSize * 0.7, weight: .bold))
            }
            
            // Parity Indicator
            if let p = cell.parity {
                let color = p == "1" ? Color.blue : Color.orange
                Circle().stroke(color, lineWidth: 2).padding(2)
            }
        }
    }
}
