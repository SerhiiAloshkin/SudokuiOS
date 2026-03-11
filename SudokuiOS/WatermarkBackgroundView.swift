import SwiftUI

struct WatermarkBackgroundView: View {
    // Collect all unique icons from our rule types
    private let icons: [String] = SudokuRuleType.allCases.map { $0.iconName }
    
    // Grid configuration
    private let iconSize: CGFloat = 65
    private let spacing: CGFloat = 40
    
    var body: some View {
        GeometryReader { geometry in
            let columns = Int(geometry.size.width / (iconSize + spacing)) + 2
            let rows = Int(geometry.size.height / (iconSize + spacing)) + 2
            
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let index = (row * columns + col) % icons.count
                            iconView(name: icons[index], row: row, col: col)
                        }
                    }
                    // Stagger every other row
                    .offset(x: row % 2 == 0 ? 0 : -(iconSize + spacing) / 2)
                }
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
    
    @ViewBuilder
    private func iconView(name: String, row: Int, col: Int) -> some View {
        // Deterministic but "random" looking rotation and scale
        let rotation = Double((row * 7 + col * 13) % 4) * 15.0 - 30.0
        let scale = 1.0 + Double((row * 3 + col * 5) % 3) * 0.1
        
        Group {
            if name == "knight_icon" {
                Image("knight_icon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
            } else {
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: iconSize, height: iconSize)
        .foregroundColor(Color.themeBlue)
        .opacity(0.05)
        .rotationEffect(.degrees(rotation))
        .scaleEffect(scale)
    }
}

#Preview {
    WatermarkBackgroundView()
        .background(Color(uiColor: .systemBackground))
}
