import SwiftUI

struct LevelPreviewBoard: View {
    let level: SudokuLevel
    
    // Internal State for parsed data
    private var cellValues: [Int] = Array(repeating: 0, count: 81)
    private var cellNotes: [Int: Set<Int>] = [:]
    private var cellColors: [Int: Int] = [:] // Index -> ColorIndex
    private var cellCrosses: [Int: Bool] = [:]
    
    // Grid Config
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)
    
    init(level: SudokuLevel) {
        self.level = level
        parseData()
    }
    
    // Data Parsing
    private mutating func parseData() {
        // 1. Board Values - Show ONLY the initial puzzle (Clues), ignoring user progress
        let boardString = level.board ?? String(repeating: "0", count: 81)
        for (i, char) in boardString.enumerated() {
            if i < 81 {
                cellValues[i] = Int(String(char)) ?? 0
            }
        }
        
        // 2. Notes - Hidden in Preview
        // cellNotes = [:]
        
        // 3. Colors - Hidden in Preview (User Coloring)
        // cellColors = [:]
        
        // 4. Crosses - Hidden in Preview
        // cellCrosses = [:]
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            // Calculate Cell Size based on Grid (ignoring outside clues for internal calculations if this view is JUST the grid)
            // But if we want to include Clues in this view, we need a layout similar to SudokuBoardView.
            // For Simplicity and "Unified Board", I'll implement the Layout with Clues if they exist.
            
            let hasLeftClues = level.rowClues != nil
            let hasTopClues = level.colClues != nil
            
            let totalCols = CGFloat(hasLeftClues ? 10 : 9)
            let cellSize = (availableWidth / totalCols).rounded(.down)
            let boardSize = cellSize * 9
            
            HStack(alignment: .top, spacing: 0) {
                // MARK: - Left Clues
                if let rowClues = level.rowClues {
                    VStack(spacing: 0) {
                        if hasTopClues {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                        ForEach(0..<9, id: \.self) { index in
                            let clue = rowClues[index]
                            if clue >= 0 {
                                Text("\(clue)")
                                    .font(.system(size: cellSize * 0.4, weight: .semibold)) // Scaled Font
                                    .foregroundColor(.gray)
                                    .frame(width: cellSize, height: cellSize)
                            } else {
                                Color.clear.frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
                
                // MARK: - Main Grid Block
                VStack(spacing: 0) {
                    // MARK: - Top Clues
                    if let colClues = level.colClues {
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { index in
                                let clue = colClues[index]
                                if clue >= 0 {
                                    Text("\(clue)")
                                        .font(.system(size: cellSize * 0.4, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .frame(width: cellSize, height: cellSize)
                                } else {
                                    Color.clear.frame(width: cellSize, height: cellSize)
                                }
                            }
                        }
                    }
                    
                    // MARK: - The Stack (Bottom to Top)
                    ZStack {
                        Color(uiColor: .systemBackground)
                        
                        // 1. Odd/Even Layer
                        if let parity = level.parity {
                            OddEvenLayer(parityString: parity, cellSize: cellSize)
                        }
                        
                        // 2. Sandwich Layer (Crosses are inside cells, but if we had a dedicated layer it'd go here)
                        // This usually implies "Visuals" related to Sandwich.
                        // Crosses + Highlighted Regions.
                        // We only have "Crosses" which are cell-based.
                        
                        // 3. Thermo Layer
                        // User requested Order: Thermo -> Kropki -> Arrow -> Grid
                        // But verifying visibility:
                        // Thermo is usually translucent gray.
                        ThermoOverlay(paths: level.thermoPaths)
                        

                        
                        // 5. Arrow Layer
                        if let arrows = level.arrows {
                            ArrowDrawingView(arrows: arrows)
                        }
                        
                        // 6. Killer Cages
                         if let cages = level.cages {
                            KillerCageLayer(cages: cages)
                        }
                        
                        // 7. Sudoku Grid View (Cells + Lines)
                        LazyVGrid(columns: columns, spacing: 0) {
                            ForEach(0..<81, id: \.self) { index in
                                let val = cellValues[index]
                                let notes = cellNotes[index] ?? []
                                let colorIdx = cellColors[index]
                                let color = colorIdx != nil ? SudokuGameViewModel.palette[colorIdx!] : nil
                                let isClue = isClue(at: index)
                                let hasCross = cellCrosses[index] ?? false
                                
                                PreviewSudokuCellView(
                                    value: val,
                                    notes: notes,
                                    color: color,
                                    isClue: isClue,
                                    isError: false, // Preview has no errors
                                    hasCross: hasCross,
                                    cellSize: cellSize
                                )
                                .frame(height: cellSize)
                            }
                        }
                        
                        // 8. Board Overlay (Lines)
                        SudokuBoardOverlay()
                            
                        // 9. Kropki Layer (Topmost to cover lines for solid appearance)
                        if let wDots = level.white_dots, let bDots = level.black_dots {
                            KropkiLayer(whiteDots: wDots, blackDots: bDots, errorBorders: [], backgroundColor: .clear)
                        }
                    }
                    .frame(width: boardSize, height: boardSize)
                    .border(Color.primary, width: 2)
                }
            }
        }
    }
    
    private func isClue(at index: Int) -> Bool {
        guard let initial = level.board, index < initial.count else { return true }
        let charIndex = initial.index(initial.startIndex, offsetBy: index)
        return initial[charIndex] != "0"
    }
}
