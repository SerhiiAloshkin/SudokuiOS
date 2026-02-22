import SwiftUI

struct KillerCageLayer: View {
    let cages: [SudokuLevel.Cage]
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let cellSize = width / 9
            
            // 1. Draw Dashed Outlines
            Canvas { context, size in
                for cage in cages {
                    let path = tracePerimeter(cage: cage, cellSize: cellSize)
                    
                    context.stroke(
                        path,
                        with: .color(.primary.opacity(0.8)), // Darker for visibility
                        style: StrokeStyle(lineWidth: 1, lineCap: .butt, lineJoin: .miter, dash: [3, 3])
                    )
                }
            }
            
            // 2. Draw Sum Labels
            ForEach(0..<cages.count, id: \.self) { index in
                let cage = cages[index]
                if let topLeft = cage.topLeft {
                    // Position aligned with top-left corner
                    let offset: CGFloat = 2 // Constant offset to clear thick borders
                    Text("\(cage.sum)")
                        .font(.system(size: cellSize * 0.2, weight: .bold)) // Relativized (approx 8pt at 40px)
                        .foregroundColor(.primary)
                        // No padding to minimize footprint
                        .position(
                            x: (CGFloat(topLeft[1]) * cellSize) + offset + 5, // width/2 approx 5
                            y: (CGFloat(topLeft[0]) * cellSize) + offset + 5
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    // Hashable Point helper
    private struct Point: Hashable {
        let row: Int
        let col: Int
    }
    
    // MARK: - Perimeter Tracing Logic
    
    private func tracePerimeter(cage: SudokuLevel.Cage, cellSize: CGFloat) -> Path {
        var path = Path()
        let inset: CGFloat = 4
        let labelGap: CGFloat = 12 // Reduced gap for smaller font
        
        // Helper to check cage membership
        let cageSet = Set(cage.cells.map { Point(row: $0[0], col: $0[1]) })
        func isIn(_ r: Int, _ c: Int) -> Bool {
            cageSet.contains(Point(row: r, col: c))
        }
        
        guard let topLeft = cage.topLeft else { return path }
        let startCell = Point(row: topLeft[0], col: topLeft[1])
        
        // 1. Start Point (Top edge of Top-Left cell, offset by gap)
        let startX = (CGFloat(startCell.col) * cellSize) + inset + labelGap
        let startY = (CGFloat(startCell.row) * cellSize) + inset
        
        // 2. Initial Segment (Top Edge of Top-Left cell) leads to Top-Right corner?
        // Actually, we start tracing AT Top-Right corner Vertex?
        // No, standard trace is loop.
        // We start drawing FROM (startX, startY).
        // The first vertex we aim for is Top-Right corner (r, c+1).
        
        path.move(to: CGPoint(x: startX, y: startY))
        
        // Setup Loop
        // Current Vertex we are heading TOWARDS: (r, c+1) (Top-Right of start cell)
        // Current Direction along the edge: Right (East)
        var currentV = (r: startCell.row, c: startCell.col + 1)
        var direction = Direction.right
        
        var steps = 0
        let maxSteps = 100
        
        // Target: Top-Left Corner of start cell (Final Vertex)
        // We stop when we reach it.
        
        while steps < maxSteps {
            
            // Determine NEXT Vertex and NEXT Direction based on neighbors of currentV
            var nextDir = direction
            let vr = currentV.r
            let vc = currentV.c
            
            // Cells relative to Vertex (r,c):
            // TL: (r-1, c-1)
            // TR: (r-1, c)
            // BL: (r, c-1)
            // BR: (r, c)
            
            let tl = isIn(vr-1, vc-1)
            let tr = isIn(vr-1, vc)
            let bl = isIn(vr, vc-1)
            let br = isIn(vr, vc)
            
            // Turn Logic (Maintains Inside on Right)
            switch direction {
            case .right: // Arriving from Left (West). Inside BL. Outside TL. check BR, TR.
                if br {
                    if tr { nextDir = .up }    // Concave -> Turn Left (North)
                    else { nextDir = .right }  // Straight (East)
                } else {
                    nextDir = .down            // Convex -> Turn Right (South)
                }
            case .down: // Arriving from Top (North). Inside TL. Outside TR. Check BL, BR.
                if bl {
                    if br { nextDir = .right } // Concave -> Turn Left (East)
                    else { nextDir = .down }   // Straight (South)
                } else {
                    nextDir = .left            // Convex -> Turn Right (West)
                }
            case .left: // Arriving from Right (East). Inside TR. Outside BR. Check TL, BL.
                if tl {
                    if bl { nextDir = .down }  // Concave -> Turn Left (South)
                    else { nextDir = .left }   // Straight (West)
                } else {
                    nextDir = .up              // Convex -> Turn Right (North)
                }
            case .up: // Arriving from Bottom (South). Inside BR. Outside BL. Check TR, TL.
                if tr {
                    if tl { nextDir = .left }  // Concave -> Turn Left (West)
                    else { nextDir = .up }     // Straight (North)
                } else {
                    nextDir = .right           // Convex -> Turn Right (East)
                }
            }
            
            // Calculate Inset Point for Vertex (vr, vc)
            // Based on Incoming Direction and Outgoing Direction
            let d = inset
            var dx: CGFloat = 0
            var dy: CGFloat = 0
            
            func getOffset(_ dir: Direction) -> (x: CGFloat, y: CGFloat) {
                switch dir {
                case .down: return (-d, 0)  // Shift Left
                case .up:   return (+d, 0)  // Shift Right
                case .right: return (0, +d) // Shift Down (Start Top Edge -> Inset Down)
                case .left:  return (0, -d) // Shift Up (Start Bottom Edge -> Inset Up)
                }
            }
            
            let off1 = getOffset(direction) // Incoming
            
            if direction == nextDir {
                // Straight segment: Use single offset
                dx = off1.x
                dy = off1.y
            } else {
                // Turn: Combine offsets (Intersection of two inset lines)
                let off2 = getOffset(nextDir)
                dx = off1.x + off2.x
                dy = off1.y + off2.y
            }
            
            // Check for Concave Corner (Inner Turn) adjustment??
            // For inset boundary, Concave corner (reflex angle of polygon)
            // means we are "wrapping around" a dent.
            // The inset polygon moves "away" from the corner.
            // (dx, dy) logic above sums offsets.
            // E.g. Right -> Up (Concave).
            // Right (0, -d). Up (+d, 0).
            // Sum: (+d, -d).
            // Vertex is Bottom-Right relative to open space.
            // Logic holds.
            
            // Target Point
            let pX = CGFloat(vc) * cellSize + dx
            let pY = CGFloat(vr) * cellSize + dy
            let targetPoint = CGPoint(x: pX, y: pY)
            
            // Check Termination Condition (Reached Start of Left Edge)
            // Final leg corresponds to direction .up (North) arriving at Top-Left Vertex
            // Vertex (r, c) == (startCell.row, startCell.col)
            if vr == startCell.row && vc == startCell.col {
                // We are at Top-Left corner.
                // We should stop SHORT of the corner for the gap (Left Edge Gap).
                // Incoming direction should be .up (North).
                // Target Y should be limit: startY + gap? No, startY is Top edge.
                // Left edge Gap Limit: minY + inset + gap.
                // Current TargetY (pY) is minY + inset + dy. (dy=0 for Straight Up? No up is +d? No +d is X).
                // For Up->Right (Convex corner at Top-Left):
                // In: Up (+d, 0). Out: Right (0, -d).
                // Corner logic: (+d, -d). Top-Right of cell? No.
                // Top-Left Vertex.
                // This Vertex is Top-Left of StartCell.
                // We are tracing the Left Edge (Up).
                // We terminate here.
                
                // Adjusted End Point for Gap
                let gapEndPoint = CGPoint(x: pX, y: pY + labelGap) // End lower than corner
                path.addLine(to: gapEndPoint)
                break
            } else {
                path.addLine(to: targetPoint)
            }
            
            // Advance
            currentV = (r: vr + nextDir.dr, c: vc + nextDir.dc)
            direction = nextDir
            steps += 1
        }
        
        return path
    }
    
    enum Direction {
        case up, down, left, right
        
        var dr: Int { 
            switch self { case .up: return -1; case .down: return 1; default: return 0 }
        }
        var dc: Int {
            switch self { case .left: return -1; case .right: return 1; default: return 0 }
        }
    }
}

#Preview {
    let mockCage = SudokuLevel.Cage(sum: 10, cells: [[0,0], [0,1], [1,1]])
    KillerCageLayer(cages: [mockCage])
        .frame(width: 300, height: 300)
}
