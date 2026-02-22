import SwiftUI

struct OddEvenLayer: View {
    let parityString: String // 81 chars: '0'=None, '1'=Odd, '2'=Even
    let cellSize: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    init(parityString: String, cellSize: CGFloat) {
        self.parityString = parityString
        self.cellSize = cellSize
    }
    
    var body: some View {
        let chars = Array(parityString)

        
        ZStack(alignment: .topLeading) {
            ForEach(0..<81, id: \.self) { index in
                if index < chars.count {
                    let char = chars[index]
                    if char != "0" {
                        let row = index / 9
                        let col = index % 9
                        
                        // Position calculation
                        let x = CGFloat(col) * cellSize + (cellSize / 2)
                        let y = CGFloat(row) * cellSize + (cellSize / 2)
                        


                        
                        Group {
                            if char == "1" {
                                // Odd: Circle Frame
                                // 2pt Stroke, Neutral Gray
                                Circle()
                                    .stroke(Color.oddEvenFrame, lineWidth: 2)
                                    .frame(width: cellSize * 0.75, height: cellSize * 0.75)
                            } else if char == "2" {
                                // Even: Rounded Square Frame
                                // 2pt Stroke, Neutral Gray
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.oddEvenFrame, lineWidth: 2)
                                    .frame(width: cellSize * 0.75, height: cellSize * 0.75)
                            }
                        }
                        .position(x: x, y: y)
                    }
                }
            }
        }
        .frame(width: cellSize * 9, height: cellSize * 9)
        .allowsHitTesting(false) // Crucial: Overlay shouldn't block touches
    }
}
