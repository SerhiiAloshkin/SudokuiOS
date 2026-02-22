import SwiftUI

struct ArrowDrawingView: View {
    let arrows: [SudokuLevel.Arrow]
    
    init(arrows: [SudokuLevel.Arrow]) {
        self.arrows = arrows
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let cellSize = width / 9
            
            Canvas { context, size in
                for arrow in arrows {
                    guard arrow.bulb.count == 2, !arrow.line.isEmpty else { continue }
                    
                    // Constants
                    let bulbRadius = (cellSize * 0.8) / 2
                    let strokeWidth: CGFloat = cellSize * 0.12 // Proportional thickness
                    let arrowColor = Color.gray // Opaque for compositing
                    
                    // 1. Draw Bulb (Circle) - Stroke
                    let bulbRow = arrow.bulb[0]
                    let bulbCol = arrow.bulb[1]
                    let bulbCenter = getCenter(row: bulbRow, col: bulbCol, cellSize: cellSize)
                    
                    let bulbRect = CGRect(
                        x: bulbCenter.x - bulbRadius,
                        y: bulbCenter.y - bulbRadius,
                        width: bulbRadius * 2,
                        height: bulbRadius * 2
                    )
                    
                    context.stroke(
                        Circle().path(in: bulbRect),
                        with: .color(arrowColor),
                        lineWidth: 2 // Bulb stroke
                    )
                    
                    // 2. Calculate Line Path
                    // Trace path: Bulb Edge -> Point 1 -> ... -> Last Point
                    
                    // First segment: Bulb -> Line[0]
                    let firstTarget = getCenter(row: arrow.line[0][0], col: arrow.line[0][1], cellSize: cellSize)
                    
                    let dx = firstTarget.x - bulbCenter.x
                    let dy = firstTarget.y - bulbCenter.y
                    let distance = sqrt(dx*dx + dy*dy)
                    
                    // Add intermediate points
                    // We trim the LAST segment so the line doesn't poke through the sharp arrow tip
                    // The line is 5px wide. The arrow tip is 0px wide.
                    // We stop the line 'trimDistance' away from the tip.
                    let arrowLength: CGFloat = 15
                    let trimDistance = arrowLength - 4 // Stop 4px "deep" inside the arrow (11px from tip).
                    
                    var points: [CGPoint] = []
                    
                    // Start Point (at Bulb Edge)
                    if distance > 0 {
                        let ratio = bulbRadius / distance
                        points.append(CGPoint(x: bulbCenter.x + dx * ratio, y: bulbCenter.y + dy * ratio))
                    } else {
                        points.append(bulbCenter)
                    }
                    
                    // Intermediate Points
                    for i in 0..<arrow.line.count {
                        points.append(getCenter(row: arrow.line[i][0], col: arrow.line[i][1], cellSize: cellSize))
                    }
                    
                    // Apply Trimming to the last segment
                    if points.count >= 2 {
                         let end = points.last!
                         let prev = points[points.count - 2]
                         let sdx = end.x - prev.x
                         let sdy = end.y - prev.y
                         let segDist = sqrt(sdx*sdx + sdy*sdy)
                         
                         if segDist > trimDistance {
                             let ratio = (segDist - trimDistance) / segDist
                             let newEnd = CGPoint(
                                 x: prev.x + sdx * ratio,
                                 y: prev.y + sdy * ratio
                             )
                             points[points.count - 1] = newEnd
                         } else {
                             // Segment too short, just squash it to prev (or keep it?)
                             // If it's too short, the arrowhead covers the whole segment anyway.
                             // But let's be safe and set it to prev to avoid weird artifacts.
                             points[points.count - 1] = prev
                         }
                    }
                    
                    // Build path from points
                    if !points.isEmpty {
                        var path = Path()
                        path.move(to: points[0])
                        for i in 1..<points.count {
                            path.addLine(to: points[i])
                        }
                        context.stroke(path, with: .color(arrowColor), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt, lineJoin: .round))
                    }
                    
                    // 3. Draw Arrowhead
                    if let lastCoord = arrow.line.last {
                        let trueEnd = getCenter(row: lastCoord[0], col: lastCoord[1], cellSize: cellSize)
                        
                        // Direction for arrowhead rotation
                        let prevPoint: CGPoint
                        if arrow.line.count >= 2 {
                             let prevCoord = arrow.line[arrow.line.count - 2]
                             prevPoint = getCenter(row: prevCoord[0], col: prevCoord[1], cellSize: cellSize)
                        } else {
                             // Fallback
                             prevPoint = bulbCenter
                        }
                        
                        drawArrowHead(context: context, to: trueEnd, from: prevPoint, color: arrowColor, length: arrowLength)
                    }
                }
            }
            .opacity(0.4) // Apply opacity to the flattened layer
        }
        .allowsHitTesting(false)
    }
    
    private func getCenter(row: Int, col: Int, cellSize: CGFloat) -> CGPoint {
        return CGPoint(
            x: (CGFloat(col) + 0.5) * cellSize,
            y: (CGFloat(row) + 0.5) * cellSize
        )
    }
    
    private func drawArrowHead(context: GraphicsContext, to end: CGPoint, from start: CGPoint, color: Color, length: CGFloat) {
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowAngle: CGFloat = .pi / 6 
        
        var path = Path()
        path.move(to: end) // Tip
        
        let x1 = end.x - length * cos(angle - arrowAngle)
        let y1 = end.y - length * sin(angle - arrowAngle)
        path.addLine(to: CGPoint(x: x1, y: y1))
        
        let x2 = end.x - length * cos(angle + arrowAngle)
        let y2 = end.y - length * sin(angle + arrowAngle)
        path.addLine(to: CGPoint(x: x2, y: y2))
        
        path.closeSubpath()
        
        // Fill it
        context.fill(path, with: .color(color))
    }
}

#Preview {
    // Mock Data
    let mockArrows = [
        SudokuLevel.Arrow(bulb: [0,0], line: [[0,1], [0,2], [1,2]])
    ]
    ArrowDrawingView(arrows: mockArrows)
        .frame(width: 300, height: 300)
        .border(Color.black)
}
