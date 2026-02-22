import SwiftUI

// MARK: - Simplified Preview Cell
struct PreviewSudokuCellView: View {
    let value: Int
    let notes: Set<Int>
    let color: Color?
    let isClue: Bool
    let isError: Bool
    let hasCross: Bool
    let cellSize: CGFloat
    
    // Static Palette for preview if needed, or pass color directly
    // Using standard colors
    
    var body: some View {
        ZStack {
            // 1. Background
            Rectangle()
                .fill(color ?? Color.clear)
            
            // 3. Content
            if value != 0 {
                Text("\(value)")
                    .font(.system(size: cellSize * 0.7, weight: isError ? .bold : .medium, design: .rounded))
                    .foregroundColor(isClue ? .primary : (isError ? .red : .blue))
            } else if !notes.isEmpty {
                noteGrid
            }
            
            // 3.5 Cross Overlay
            if hasCross {
                Image(systemName: "multiply")
                    .font(.system(size: cellSize * 0.6, weight: .light))
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(Color.gray.opacity(0.5), lineWidth: 0.5)
        )
        // .aspectRatio(1, contentMode: .fit) // Handled by Grid usually
        .clipped()
    }
    
    private var noteGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<3) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3) { c in
                        let num = r * 3 + c + 1
                        if notes.contains(num) {
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
        .padding(2) 
    }
}

// MARK: - Reusable Grid Overlay
struct SudokuBoardOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let colWidth = width / 9
                let rowHeight = height / 9
                
                // Draw vertical lines after col 3 and 6
                for i in [3, 6] {
                    let x = CGFloat(i) * colWidth
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))
                }
                
                // Draw horizontal lines after row 3 and 6
                for i in [3, 6] {
                    let y = CGFloat(i) * rowHeight
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.primary, lineWidth: 2) // Adaptive Thick line
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Thermo Overlay
struct ThermoOverlay: View {
    let paths: [[[Int]]]?
    
    var body: some View {
        GeometryReader { geometry in
            if let paths = paths {
                let width = geometry.size.width
                let cellSize = width / 9.0
                
                ForEach(0..<paths.count, id: \.self) { i in
                    let path = paths[i]
                    if !path.isEmpty {
                        ZStack {
                            // 1. Draw Line
                            Path { p in
                                let start = path[0]
                                let startX = CGFloat(start[1]) * cellSize + cellSize/2
                                let startY = CGFloat(start[0]) * cellSize + cellSize/2
                                p.move(to: CGPoint(x: startX, y: startY))
                                
                                for j in 1..<path.count {
                                    let coord = path[j]
                                    let x = CGFloat(coord[1]) * cellSize + cellSize/2
                                    let y = CGFloat(coord[0]) * cellSize + cellSize/2
                                    p.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            .stroke(Color.gray, style: StrokeStyle(lineWidth: cellSize * 0.35, lineCap: .round, lineJoin: .round))
                            
                            // 2. Draw Bulb
                            let bulbCoord = path[0]
                            let bx = CGFloat(bulbCoord[1]) * cellSize + cellSize/2
                            let by = CGFloat(bulbCoord[0]) * cellSize + cellSize/2
                            
                            Circle()
                                .fill(Color.gray)
                                .frame(width: cellSize * 0.85, height: cellSize * 0.85)
                                .position(x: bx, y: by)
                        }
                        .compositingGroup()
                        .opacity(0.4)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
