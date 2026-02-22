import SwiftUI

struct KropkiLayer: View {
    let whiteDots: [SudokuLevel.KropkiDot]
    let blackDots: [SudokuLevel.KropkiDot]
    let errorBorders: Set<KropkiBorder>
    let backgroundColor: Color
    
    init(whiteDots: [SudokuLevel.KropkiDot], blackDots: [SudokuLevel.KropkiDot], errorBorders: Set<KropkiBorder>, backgroundColor: Color) {
        self.whiteDots = whiteDots
        self.blackDots = blackDots
        self.errorBorders = errorBorders
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let cellSize = width / 9.0
            let dotRadius = cellSize * 0.125 // Diameter ~25%
            
            Canvas { context, size in
                // 0. Draw Masks (to hide grid lines)
                let maskRadius = dotRadius * 1.15 // 15% larger for safety
                
                // Mask for Black Dots
                for dot in blackDots {
                    let center = getMidpoint(dot, cellSize: cellSize)
                    let rect = CGRect(
                        x: center.x - maskRadius,
                        y: center.y - maskRadius,
                        width: maskRadius * 2,
                        height: maskRadius * 2
                    )
                    // Use system background (white/black depending on theme, or explicit). 
                    // LevelPreview uses systemBackground.
                    context.fill(Circle().path(in: rect), with: .color(backgroundColor))
                }
                
                // Mask for White Dots
                for dot in whiteDots {
                    let center = getMidpoint(dot, cellSize: cellSize)
                    let rect = CGRect(
                        x: center.x - maskRadius,
                        y: center.y - maskRadius,
                        width: maskRadius * 2,
                        height: maskRadius * 2
                    )
                    context.fill(Circle().path(in: rect), with: .color(backgroundColor))
                }

                // 1. Draw Black Dots
                for dot in blackDots {
                    let center = getMidpoint(dot, cellSize: cellSize)
                    let rect = CGRect(
                        x: center.x - dotRadius,
                        y: center.y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(Circle().path(in: rect), with: .color(.black))
                }
                
                // 2. Draw White Dots
                for dot in whiteDots {
                    let center = getMidpoint(dot, cellSize: cellSize)
                    let rect = CGRect(
                        x: center.x - dotRadius,
                        y: center.y - dotRadius,
                        width: dotRadius * 2,
                        height: dotRadius * 2
                    )
                    context.fill(Circle().path(in: rect), with: .color(.white))
                    context.stroke(
                        Circle().path(in: rect),
                        with: .color(.black),
                        lineWidth: 1.5
                    )
                }
                
                // 3. Draw Error Borders (Red Lines)
                let errorLen = cellSize * 0.6
                
                for border in errorBorders {
                    let c1 = CGFloat(border.c1)
                    let c2 = CGFloat(border.c2)
                    let r1 = CGFloat(border.r1)
                    let r2 = CGFloat(border.r2)
                    
                    let xCenter = ((c1 + c2) / 2.0 * cellSize) + (cellSize / 2.0)
                    let yCenter = ((r1 + r2) / 2.0 * cellSize) + (cellSize / 2.0)
                    
                    let path = Path { p in
                        if border.r1 == border.r2 {
                            // Vertical Line (Horizontal Neighbors)
                            p.move(to: CGPoint(x: xCenter, y: yCenter - errorLen/2))
                            p.addLine(to: CGPoint(x: xCenter, y: yCenter + errorLen/2))
                        } else {
                            // Horizontal Line (Vertical Neighbors)
                            p.move(to: CGPoint(x: xCenter - errorLen/2, y: yCenter))
                            p.addLine(to: CGPoint(x: xCenter + errorLen/2, y: yCenter))
                        }
                    }
                    context.stroke(path, with: .color(.red), lineWidth: 3)
                }
            }
        }
        .allowsHitTesting(false)
    }
    
    private func getMidpoint(_ dot: SudokuLevel.KropkiDot, cellSize: CGFloat) -> CGPoint {
        let r1 = CGFloat(dot.r1)
        let c1 = CGFloat(dot.c1)
        let r2 = CGFloat(dot.r2)
        let c2 = CGFloat(dot.c2)
        
        let x1 = c1 * cellSize + cellSize / 2
        let y1 = r1 * cellSize + cellSize / 2
        
        let x2 = c2 * cellSize + cellSize / 2
        let y2 = r2 * cellSize + cellSize / 2
        
        return CGPoint(x: (x1 + x2) / 2, y: (y1 + y2) / 2)
    }
}

#Preview {
    let wDots = [SudokuLevel.KropkiDot(r1: 0, c1: 0, r2: 0, c2: 1)]
    let bDots = [SudokuLevel.KropkiDot(r1: 1, c1: 0, r2: 2, c2: 0)]
    KropkiLayer(whiteDots: wDots, blackDots: bDots, errorBorders: [], backgroundColor: .white)
        .frame(width: 300, height: 300)
        .border(Color.gray)
}
