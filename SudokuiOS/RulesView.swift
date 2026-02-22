import SwiftUI

struct RulesView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AppSettings.self) var settings // Inject Settings from Environment
    
    let ruleType: SudokuRuleType
    var isNegative: Bool = false
    
    @State private var currentTab = 0
    
    var body: some View {
        NavigationStack {
            TabView(selection: $currentTab) {
                // 1. Classic Rules (Always First)
                StaticRuleCardView(ruleType: .classic)
                    .tag(0)
                
                // 2. Specific Variant Rules (If applicable)
                if ruleType != .classic {
                    StaticRuleCardView(ruleType: ruleType)
                        .tag(1)
                    
                    // 3. Negative Constraint Page (Conditional)
                    if ruleType == .kropki && isNegative {
                        StaticRuleCardView(ruleType: .kropki, isNegativeExplanation: true)
                            .tag(2)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .overlay(navigationArrows) // Persistent Navigation Arrows
            .navigationTitle("How to Play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        // Mark Tutorial as Seen
                        settings.hasSeenTutorial = true
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            // Backup: Mark as seen when dismissed via other means (drag)
            settings.hasSeenTutorial = true
        }
    }
    
    // Computed property for total pages
    var pageCount: Int {
        if ruleType == .classic { return 1 }
        if ruleType == .kropki && isNegative { return 3 }
        return 2
    }
    
    // Overlay for Navigation Arrows
    @ViewBuilder
    var navigationArrows: some View {
        HStack {
            // Left Arrow (Previous)
            if currentTab > 0 {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.easeInOut) {
                        currentTab -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2.weight(.bold))
                        .foregroundColor(Color("ThemeBlue"))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        // Add shadow for visibility on white/light backgrounds
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .padding(.leading, 16)
            }
            
            Spacer()
            
            // Right Arrow (Next)
            if currentTab < pageCount - 1 {
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    withAnimation(.easeInOut) {
                        currentTab += 1
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2.weight(.bold))
                        .foregroundColor(Color("ThemeBlue"))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .padding(.trailing, 16)
            }
        }
        .allowsHitTesting(true) // Ensure buttons catch taps
    }
}

// MARK: - Subcomponents

struct StaticRuleCardView: View {
    let ruleType: SudokuRuleType
    var isNegativeExplanation: Bool = false // New flag for Negative Constraint page
    
    var body: some View {
        GeometryReader { geometry in
            let gridSize = geometry.size.width * 0.5
            
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Title & Description
                    VStack(spacing: 8) {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundColor(isNegativeExplanation ? .red : Color("ThemeBlue"))
                            .padding(isNegativeExplanation ? EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12) : EdgeInsets())
                            .background(isNegativeExplanation ? Color.red.opacity(0.15) : Color.clear)
                            .cornerRadius(isNegativeExplanation ? 8 : 0)
                        
                        Text(description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
                    // 2. Static Visualization (Vertical Stack)
                    VStack(spacing: 20) { // Reduced spacing from 40
                        // INCORRECT Example
                        RuleExampleFragment(
                            isCorrect: false,
                            content: incorrectContent,
                            topClues: nil,
                            leftClues: ruleType == .sandwich ? [nil, 7, nil] : nil, // Horizontal Clue
                            thermoPath: ruleType == .thermo ? incorrectThermoPath : nil,
                            arrowPath: ruleType == .arrow ? incorrectArrowPath : nil,
                            killerCages: ruleType == .killer ? incorrectKillerCages : nil,
                            kropkiDots: ruleType == .kropki ? incorrectKropkiDots : nil,
                            oddEvenShapes: ruleType == .oddEven ? oddEvenShapes : nil,
                            gridSize: gridSize
                        )
                        
                        // CORRECT Example
                        RuleExampleFragment(
                            isCorrect: true,
                            content: correctContent,
                            topClues: nil,
                            leftClues: ruleType == .sandwich ? [nil, 8, nil] : nil, // Horizontal Clue
                            thermoPath: ruleType == .thermo ? correctThermoPath : nil,
                            arrowPath: ruleType == .arrow ? correctArrowPath : nil,
                            killerCages: ruleType == .killer ? correctKillerCages : nil,
                            kropkiDots: ruleType == .kropki ? correctKropkiDots : nil,
                            oddEvenShapes: ruleType == .oddEven ? oddEvenShapes : nil,
                            gridSize: gridSize
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40) // Safe area padding
                }
            }
        }
    }
    
    // MARK: - Content Helpers
    
    var title: String {
        switch ruleType {
        case .classic: return "NO REPEATS"
        case .nonConsecutive: return "NON-CONSECUTIVE"
        case .knight: return "KNIGHT MOVE"
        case .king: return "KING MOVE"
        case .killer: return "KILLER CAGES"
        case .arrow: return "ARROW SUMS"
        case .thermo: return "THERMOMETERS"
        case .kropki:
            if isNegativeExplanation {
                return "NEGATIVE CONSTRAINT"
            }
            return "KROPKI DOTS"
        case .oddEven: return "ODD / EVEN"
        case .sandwich: return "SANDWICH"
        }
    }
    
    var description: String {
        switch ruleType {
        case .classic: return "Numbers cannot repeat in the same row, column, or 3x3 box."
        case .nonConsecutive: return "Adjacent cells cannot contain consecutive numbers (e.g. 4 & 5)."
        case .knight: return "Review the Knight's move (L-shape). Same numbers cannot be a Knight's move apart."
        case .king: return "Same numbers cannot be in any adjacent cell, including diagonals."
        case .killer: return "Numbers in cages must sum to the corner clue and cannot repeat."
        case .arrow: return "Numbers along the arrow must sum to the number in the circle."
        case .thermo: return "Numbers must strictly increase from the bulb to the tip."
        case .kropki:
            if isNegativeExplanation {
                return "If there is NO dot between two cells, their difference CANNOT be 1 and their ratio CANNOT be 2:1."
            }
            return "White dot: Difference is 1. Black dot: Ratio is 2:1. (1 & 2 can have either)."
        case .oddEven: return "Blue Square-framed cells are Even (2, 4, 6, 8). Blue Circle-framed cells are Odd (1, 3, 5, 7, 9)."
        case .sandwich: return "Clues outside the grid show the sum of digits sandwiched between 1 and 9."
        }
    }
    
    // (Row, Col, Value, isTarget)
    // Target gets styled background.
    typealias CellData = (r: Int, c: Int, val: String, isTarget: Bool)
    
    // Kropki Dot Data
    struct KropkiDotDisplayData {
        let p1: (Int, Int)
        let p2: (Int, Int)
        let type: KropkiType
    }
    
    // Odd/Even Shape Data
    struct OddEvenDisplayData {
        let r: Int
        let c: Int
        let isSquare: Bool // True = Square (Even), False = Circle (Odd)
    }
    
    enum KropkiType {
        case white // Diff 1
        case black // Ratio 2:1
        case none  // No dot (for visual clarity in negative constraint if we want to explicitly show 'nothing')
    }
    
    var incorrectKropkiDots: [KropkiDotDisplayData] {
        if isNegativeExplanation {
            // Negative Constraint: No dot shown, but values imply relationship
            return [] 
        } else {
            // Standard: White Dot [3,5] (Diff 2, Error) AND Black Dot [4,7] (Ratio 7/4, Error)
            return [
                KropkiDotDisplayData(p1: (0,0), p2: (0,1), type: .white),
                KropkiDotDisplayData(p1: (1,1), p2: (1,2), type: .black)
            ]
        }
    }
    
    var correctKropkiDots: [KropkiDotDisplayData] {
        if isNegativeExplanation {
            // Negative Constraint: No dot, valid non-related pair
            return []
        } else {
            // Standard: White Dot [4,5] (Diff 1) AND Black Dot [3,6] (Ratio 2)
            return [
                KropkiDotDisplayData(p1: (0,0), p2: (0,1), type: .white),
                KropkiDotDisplayData(p1: (1,1), p2: (1,2), type: .black)
            ]
        }
    }
    
    // New Thermo Path Data: Array of (row, col) tuples
    var incorrectThermoPath: [(Int, Int)] {
        return [(2,0), (1,1), (0,2)] // Bottom-Left to Top-Right diagonal
    }
    
    var correctThermoPath: [(Int, Int)] {
        return [(2,0), (1,1), (0,2)] // Bottom-Left to Top-Right diagonal
    }
    
    // New Odd/Even Shapes
    var oddEvenShapes: [OddEvenDisplayData] {
        return [
            OddEvenDisplayData(r: 0, c: 0, isSquare: true),  // Even container
            OddEvenDisplayData(r: 0, c: 1, isSquare: false) // Odd container
        ]
    }
    
    // New Arrow Path Data: Circle -> Line
    var incorrectArrowPath: [(Int, Int)] {
        // Circle at (0,0), Arrow to (0,1) -> (0,2)
        return [(0,0), (0,1), (0,2)]
    }
    
    var correctArrowPath: [(Int, Int)] {
        return [(0,0), (0,1), (0,2)]
    }
    
    // New Killer Cage Data: (Clue, Cells)
    // Using a simple struct or tuple for internal use
    struct KillerCageDisplayData {
        let clue: Int
        let cells: [(Int, Int)]
    }
    
    var incorrectKillerCages: [KillerCageDisplayData] {
        return [KillerCageDisplayData(clue: 7, cells: [(0,0), (0,1)])]
    }
    
    var correctKillerCages: [KillerCageDisplayData] {
        return [KillerCageDisplayData(clue: 7, cells: [(0,0), (0,1)])]
    }
    
    var incorrectContent: [CellData] {
        switch ruleType {
        case .classic: return [(0, 0, "5", true), (0, 1, "3", false), (0, 2, "5", true)]
        case .nonConsecutive: return [(1, 1, "5", true), (1, 2, "4", true)]
        case .knight: return [(0, 0, "5", true), (1, 2, "5", true)]
        case .king: return [(1, 1, "5", true), (0, 0, "5", true)]
        case .killer:
             // Incorrect: Cage 7 (Cells 0,0 & 0,1) -> [3, 5] (Sum 8)
             return [
                 (0, 0, "3", false),
                 (0, 1, "5", true) // Error
             ]
        case .arrow:
             // Incorrect: Circle 9, Arrow [5, 6] (Sum 11)
             // Path: (0,0) -> (0,1) -> (0,2)
             return [
                 (0, 0, "9", false), // Circle
                 (0, 1, "5", false),
                 (0, 2, "6", true)   // Error
             ]
        case .thermo:
            // Incorrect: 1 -> 5 -> 4 (Decreasing at tip)
            return [
                (2, 0, "1", false), // Bulb
                (1, 1, "5", false),
                (0, 2, "4", true)   // Tip (Error)
            ]
        case .kropki:
            if isNegativeExplanation {
                // Negative Constraint:
                // Incorrect: Center 4. Right 5 (Diff 1). Top 8 (Ratio 2).
                // Both 5 and 8 are errors because they imply a dot when none exists.
                return [
                    (1, 1, "4", false),
                    (1, 2, "5", true), // Error: Diff 1
                    (0, 1, "8", true)  // Error: Ratio 2
                ]
            } else {
                // Standard: 
                // 1. White Dot [3, 5] (Diff 2 -> Error)
                // 2. Black Dot [4, 7] (Ratio 1.75 -> Error)
                return [
                    (0, 0, "3", false), (0, 1, "5", true), // White Dot Error
                    (1, 1, "4", false), (1, 2, "7", true)  // Black Dot Error
                ]
            }
        case .oddEven: 
            // Incorrect: Square (Even) has 3 (Odd). Circle (Odd) has 6 (Even).
            return [
                (0,0, "3", true), // Error
                (0,1, "6", true)  // Error
            ]
        case .sandwich:
            // Incorrect: Sum is 8 (1+3+5+9?), clue is 7.
            // 1, 3, 5, 9 in middle row? Or Col?
            // Incorrect: Row 1 (Horizontal Example)
            // Clue 7 (Left). Values: 1, 8, 9. Sum 8.
            return [
                (1, 0, "1", false),
                (1, 1, "8", true), // Highlight mismatch
                (1, 2, "9", false)
            ]
        }
    }
    
    var correctContent: [CellData] {
        switch ruleType {
        case .classic: return [(0, 0, "5", false), (0, 1, "3", false), (0, 2, "9", false)]
        case .nonConsecutive: return [(1, 1, "5", false), (1, 2, "7", false)]
        case .knight: return [(0, 0, "5", false), (1, 2, "6", false)]
        case .king: return [(1, 1, "5", false), (0, 0, "8", false)]
        case .killer:
             // Correct: Cage 7 (Cells 0,0 & 0,1) -> [3, 4] (Sum 7)
             return [
                 (0, 0, "3", false),
                 (0, 1, "4", false)
             ]
        case .arrow:
             // Correct: Circle 9, Arrow [5, 4] (Sum 9)
             return [
                 (0, 0, "9", false),
                 (0, 1, "5", false),
                 (0, 2, "4", false)
             ]
        case .thermo:
            // Correct: 1 -> 5 -> 8 (Strictly Increasing)
            return [
                (2, 0, "1", false), // Bulb
                (1, 1, "5", false),
                (0, 2, "8", false)  // Tip
            ]
        case .kropki:
            if isNegativeExplanation {
                // Negative Constraint: No dot, valid non-related pair
                // Correct: Center 4. Right 7 (Diff 3). Top 6 (Ratio 1.5).
                return [
                    (1, 1, "4", false),
                    (1, 2, "7", false),
                    (0, 1, "6", false)
                ]
            } else {
                // Standard: White dot (4-5), Black dot (3-6)
                // White at (0,0)-(0,1), Black at (1,1)-(1,2)
                return [
                    (0, 0, "4", false),
                    (0, 1, "5", false),
                    (1, 1, "3", false),
                    (1, 2, "6", false)
                ]
            }
        case .oddEven: 
            // Correct: Square (Even) has 4 (Even). Circle (Odd) has 7 (Odd).
            return [
                (0,0, "4", false),
                (0,1, "7", false)
            ]
        case .sandwich:
            // Correct: Row 1 (Horizontal Example)
            // Clue 8 (Left). Values: 1, 8, 9. Sum 8.
             return [
                (1, 0, "1", false),
                (1, 1, "8", false),
                (1, 2, "9", false)
            ]
        }
    }
}

struct RuleExampleFragment: View {
    let isCorrect: Bool
    let content: [StaticRuleCardView.CellData]
    var topClues: [Int?]? = nil
    var leftClues: [Int?]? = nil
    var thermoPath: [(Int, Int)]? = nil 
    var arrowPath: [(Int, Int)]? = nil 
    var killerCages: [StaticRuleCardView.KillerCageDisplayData]? = nil // New optional cage data

    var kropkiDots: [StaticRuleCardView.KropkiDotDisplayData]? = nil   // New optional kropki data
    var oddEvenShapes: [StaticRuleCardView.OddEvenDisplayData]? = nil  // New optional Odd/Even shapes
    
    let gridSize: CGFloat
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon (Above)
            HStack {
                Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(isCorrect ? .green : .red)
                    .background(Circle().fill(.white))
                
                Text(isCorrect ? "CORRECT" : "INCORRECT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isCorrect ? .green : .red)
                
                Spacer()
            }
            .padding(.horizontal, 40) // Align roughly with grid
            
            // Grid + Clues Container
            VStack(spacing: 2) {
                // Top Clues Row
                if let topClues = topClues {
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { col in
                            if let clue = topClues[col] {
                                Text("\(clue)")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color("ThemeBlue"))
                                    .frame(width: gridSize / 3, height: 20)
                            } else {
                                Spacer().frame(width: gridSize / 3, height: 20)
                            }
                        }
                    }
                    .padding(.bottom, 4) // Prevent touch with labels
                    // .padding(.top, 10)   // Add padding so clues don't touch labels
                }
                
                HStack(spacing: 4) {
                    // Left Clues Column
                    if let leftClues = leftClues {
                        VStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { row in
                                if let clue = leftClues[row] {
                                    Text("\(clue)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color("ThemeBlue"))
                                        .frame(width: 20, height: gridSize / 3)
                                } else {
                                    Spacer().frame(width: 20, height: gridSize / 3)
                                }
                            }
                        }
                        .padding(.trailing, 2)
                    }
                    
                    // 3x3 Grid
                    ZStack {
                        // 1. Grid Cells
                        VStack(spacing: 2) {
                            ForEach(0..<3) { row in
                                HStack(spacing: 2) {
                                    ForEach(0..<3) { col in
                                        Cell(row: row, col: col)
                                    }
                                }
                            }
                        }
                        
                         // 2. Thermo Path Overlay
                        if let path = thermoPath {
                             ThermoPathView(path: path, gridSize: gridSize)
                        }
                        
                        // 3. Arrow Path Overlay
                        if let path = arrowPath {
                            ArrowPathView(path: path, gridSize: gridSize)
                        }
                        
                        // 4. Killer Cage Overlay
                        if let cages = killerCages {
                             ForEach(0..<cages.count, id: \.self) { i in
                                 KillerCageView(cage: cages[i], gridSize: gridSize)
                             }
                        }
                        
                        // 5. Kropki Dots Overlay
                        if let dots = kropkiDots {
                            ForEach(0..<dots.count, id: \.self) { i in
                                KropkiDotView(dot: dots[i], gridSize: gridSize)
                            }
                        }
                        
                        // 6. Odd/Even Shapes Overlay
                        if let shapes = oddEvenShapes {
                            ForEach(0..<shapes.count, id: \.self) { i in
                                OddEvenShapeView(shape: shapes[i], gridSize: gridSize)
                            }
                        }
                    }
                    .padding(4)
                    .background(Color(uiColor: .systemGray6))
                    .cornerRadius(12)
                    .frame(width: gridSize, height: gridSize) // Uniform Size
                }
            }
        }
    }
    
    func Cell(row: Int, col: Int) -> some View {
        let data = content.first(where: { $0.r == row && $0.c == col })
        let text = data?.val ?? ""
        let isTarget = data?.isTarget ?? false
        
        return ZStack {
            // Background & Border
            Rectangle()
                .fill(Color(uiColor: .secondarySystemBackground))
                .border(Color.gray.opacity(0.3), width: 1)
            
            // Highlight for mistakes or special centers
            if isTarget && !isCorrect {
                 RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.red, lineWidth: 3)
            }

            if let data = data {
                 if data.val == "knight" {
                     Image("knight_icon")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .padding(gridSize * 0.15) // Scale padding
                        .foregroundColor(Color("ThemeBlue"))
                 } else if data.val == "king" {
                     Image(systemName: "crown.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(gridSize * 0.20) // Scale padding
                        .foregroundColor(Color("ThemeBlue"))
                 } else {
                     Text(text)
                        .font(.system(size: gridSize * 0.25, weight: .bold)) // Scale font
                        // Thermo Improvement: Use lighter gray for bulb/path coverage?
                        // Actually path is overlay. Text should just be on top.
                        // ZStack order in RuleExampleFragment handles this.
                        .zIndex(1) 
                        .foregroundColor(isCorrect ? Color("ThemeBlue") : (isTarget ? .red : Color("ThemeBlue")))
                 }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Helper View for drawing Kropki Dots
struct KropkiDotView: View {
    let dot: StaticRuleCardView.KropkiDotDisplayData
    let gridSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let cellW = w / 3.0
            let cellH = h / 3.0
            
            if dot.type != .none {
                // Determine center point between cells
                let p1 = ThermoPathView.center(r: dot.p1.0, c: dot.p1.1, cellW: cellW, cellH: cellH)
                let p2 = ThermoPathView.center(r: dot.p2.0, c: dot.p2.1, cellW: cellW, cellH: cellH)
                
                let cx = (p1.x + p2.x) / 2
                let cy = (p1.y + p2.y) / 2
                
                let dotSize: CGFloat = cellW * 0.25 // Reasonable dot size
                
                if dot.type == .black {
                    Circle()
                        .fill(Color.primary) // Use Primary (Black in light, White in dark - wait, board uses Black usually? Or Theme Color?)
                        // User request: "Use high-contrast White and Black assets that match the main game board."
                        // Usually Black dot is Black. White dot is White with outline.
                        // In Dark mode, Black dot needs a white stroke to be visible? Or it is inverted?
                        // Let's stick to standard Sudoku rules: Black Dot is solid, White Dot is hollow.
                        // Color.primary adapts.
                        // However, "Black Dot" implies black color.
                        // Let's use Color("ThemeBlue") or Color.black?
                        // "Match main game board". Main board uses standard white/black dots.
                        // Let's use Color.black for Black dot, with white stroke if needed for visibility?
                        // Actually, Kropki dots usually overlay grid lines.
                        .frame(width: dotSize, height: dotSize)
                        .position(x: cx, y: cy)
                } else {
                    // White Dot (Hollow)
                    ZStack {
                        Circle()
                            .fill(Color.white)
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                    }
                    .frame(width: dotSize, height: dotSize)
                    .position(x: cx, y: cy)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
struct KillerCageView: View {
    let cage: StaticRuleCardView.KillerCageDisplayData
    let gridSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let cellW = w / 3.0
            let cellH = h / 3.0
            
            // 1. Dashed Border
            // Simplified: Assuming rectangular cages for tutorial (e.g. 1x2 horizontal)
            // Find bounding box of cells
            let rows = cage.cells.map { $0.0 }
            let cols = cage.cells.map { $0.1 }
            if let minR = rows.min(), let maxR = rows.max(),
               let minC = cols.min(), let maxC = cols.max() {
                
                let rectX = CGFloat(minC) * cellW + 4 // Inset slightly
                let rectY = CGFloat(minR) * cellH + 4
                let rectW = CGFloat(maxC - minC + 1) * cellW - 8
                let rectH = CGFloat(maxR - minR + 1) * cellH - 8
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [4]))
                        .foregroundColor(Color("ThemeBlue").opacity(0.8))
                        .frame(width: rectW, height: rectH)
                        .position(x: rectX + rectW/2, y: rectY + rectH/2) // Position center
                    
                    // 2. Clue Text (Top Left of first cell)
                    // First cell in list is usually top-left
                    if let first = cage.cells.first {
                        let clueX = CGFloat(first.1) * cellW + 6
                        let clueY = CGFloat(first.0) * cellH + 6
                        
                        Text("\(cage.clue)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color("ThemeBlue"))
                            .position(x: clueX + 5, y: clueY + 5) // Slight offset for visual center of corner
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// Helper View for drawing the Arrow Path consistently
struct ArrowPathView: View {
    let path: [(Int, Int)]
    let gridSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let cellW = w / 3.0
            let cellH = h / 3.0
            
            ZStack {
                if !path.isEmpty {
                    let startCenter = ThermoPathView.center(r: path[0].0, c: path[0].1, cellW: cellW, cellH: cellH)
                    let diameter: CGFloat = cellW * 0.8 // Large circle
                    let radius: CGFloat = diameter / 2.0
                    
                    // 1. Circle Bulb (Stroke Only, No Fill)
                    Path { p in
                        let rect = CGRect(x: startCenter.x - radius, y: startCenter.y - radius, width: diameter, height: diameter)
                        p.addEllipse(in: rect)
                    }
                    .stroke(Color.gray, style: StrokeStyle(lineWidth: 4)) // Distinct stroke
                    
                    // 2. Line (Thick Stroke)
                    if path.count > 1 {
                        Path { p in
                            // Calculate line start point (Circle Edge)
                            // Direction to next point
                            let nextPoint = ThermoPathView.center(r: path[1].0, c: path[1].1, cellW: cellW, cellH: cellH)
                            let angle = atan2(nextPoint.y - startCenter.y, nextPoint.x - startCenter.x)
                            
                            // Adjust start to prevent round line cap (radius 6) from entering the hollow circle.
                            // Start at circle radius + cap radius (6) 
                            // Circle stroke is centered at radius. Cap extends back 6.
                            // So cap starts at (radius + 6) - 6 = radius.
                            // This overlaps the circle stroke perfectly without entering the hollow part.
                            let capOffset: CGFloat = 6.0 
                            let startRadius = radius + capOffset
                            
                            // Start at adjusted edge
                            let lineStart = CGPoint(
                                x: startCenter.x + startRadius * cos(angle),
                                y: startCenter.y + startRadius * sin(angle)
                            )
                            
                            p.move(to: lineStart)
                            
                            // Intermediate points
                            if path.count > 2 {
                                for i in 1..<path.count-1 {
                                    p.addLine(to: ThermoPathView.center(r: path[i].0, c: path[i].1, cellW: cellW, cellH: cellH))
                                }
                            }
                            
                            // Final point handling: Stop short at the base of the arrowhead (20pt)
                            // This ensures the round line cap (radius 6) is contained within the wider base of the arrow
                            if let last = path.last, path.count >= 2 {
                                let end = ThermoPathView.center(r: last.0, c: last.1, cellW: cellW, cellH: cellH)
                                let prev = (path.count > 2) ? ThermoPathView.center(r: path[path.count-2].0, c: path[path.count-2].1, cellW: cellW, cellH: cellH) : lineStart
                                
                                let angle = atan2(end.y - prev.y, end.x - prev.x)
                                let arrowLen: CGFloat = 20
                                
                                // Stop at the base
                                let lineEnd = CGPoint(
                                    x: end.x - arrowLen * cos(angle),
                                    y: end.y - arrowLen * sin(angle)
                                )
                                
                                p.addLine(to: lineEnd)
                            }
                        }
                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                        
                        // Arrow Head at the end
                        // Draw this independently on top (same color/group)
                        if let last = path.last, path.count >= 2 {
                             let end = ThermoPathView.center(r: last.0, c: last.1, cellW: cellW, cellH: cellH)
                             let prev = ThermoPathView.center(r: path[path.count-2].0, c: path[path.count-2].1, cellW: cellW, cellH: cellH)
                             
                             // Calculate angle
                             let angle = atan2(end.y - prev.y, end.x - prev.x)
                             let arrowLen: CGFloat = 20
                             // let arrowWidth: CGFloat = 16
                             
                             Path { p in
                                 p.move(to: end) // Tip
                                 p.addLine(to: CGPoint(x: end.x - arrowLen * cos(angle - .pi/6), y: end.y - arrowLen * sin(angle - .pi/6)))
                                 p.addLine(to: CGPoint(x: end.x - arrowLen * cos(angle + .pi/6), y: end.y - arrowLen * sin(angle + .pi/6)))
                                 p.closeSubpath()
                             }
                             .fill(Color.gray)
                        }
                    }
                }
            }
            .compositingGroup()
            .opacity(0.35) // Match the light gray transparent look
        }
        .allowsHitTesting(false)
    }
}

// Helper View for drawing the Thermometer Path consistently
struct ThermoPathView: View {
    let path: [(Int, Int)]
    let gridSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width
            let h = geometry.size.height
            let cellW = w / 3.0
            let cellH = h / 3.0
            
            // Move calculations into a helper function or pre-calculate
            // But for GeometryReader, we can just use the vars in drawing logic directly
            
            ZStack {
                if !path.isEmpty {
                    // 1. Line (Wider Stroke)
                    if path.count > 1 {
                        Path { p in
                            let start = ThermoPathView.center(r: path[0].0, c: path[0].1, cellW: cellW, cellH: cellH)
                            p.move(to: start)
                            for i in 1..<path.count {
                                p.addLine(to: ThermoPathView.center(r: path[i].0, c: path[i].1, cellW: cellW, cellH: cellH))
                            }
                        }
                        .stroke(Color.gray, style: StrokeStyle(lineWidth: 16, lineCap: .round, lineJoin: .round))
                    }
                    
                    // 2. Bulb (Solid Fill)
                    // Make bulb bigger (approx 70% of cell width)
                    Path { p in
                        let start = ThermoPathView.center(r: path[0].0, c: path[0].1, cellW: cellW, cellH: cellH)
                        let diameter: CGFloat = cellW * 0.7
                        let rect = CGRect(x: start.x - diameter/2, y: start.y - diameter/2, width: diameter, height: diameter)
                        p.addEllipse(in: rect)
                    }
                    .fill(Color.gray)
                }
            }
            .compositingGroup() // Merges layers before opacity
            .opacity(0.3) // Apply opacity to the whole shape
        }
        .allowsHitTesting(false) // Don't block touches if any
    }
    
    static func center(r: Int, c: Int, cellW: CGFloat, cellH: CGFloat) -> CGPoint {
        return CGPoint(
            x: CGFloat(c) * cellW + cellW / 2.0,
            y: CGFloat(r) * cellH + cellH / 2.0
        )
    }
}

#Preview {
    RulesView(ruleType: .nonConsecutive)
}

struct OddEvenShapeView: View {
    let shape: StaticRuleCardView.OddEvenDisplayData
    let gridSize: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            let w = geometry.size.width / 3.0
            let h = geometry.size.height / 3.0
            let x = CGFloat(shape.c) * w
            let y = CGFloat(shape.r) * h
            
            ZStack {
                if shape.isSquare {
                    // Even: Rounded Square Frame
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.oddEvenFrame, lineWidth: 2)
                        .padding(4)
                } else {
                    // Odd: Circle Frame
                    Circle()
                        .stroke(Color.oddEvenFrame, lineWidth: 2)
                        .padding(4)
                }
            }
            .frame(width: w, height: h)
            .position(x: x + w/2, y: y + h/2)
        }
        .allowsHitTesting(false)
    }
}
