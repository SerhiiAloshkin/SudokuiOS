import SwiftUI

struct SudokuLogoTitleView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 5) {
            // "SUDOKU"
            Text("SUDOKU")
                .font(.custom("AvenirNext-Bold", size: 40))
                .foregroundColor(.primary) // Adapts to Light/Dark mode
            
            // "VERSA"
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Text(String("VERSA"[index]))
                        .font(.custom("AvenirNext-Bold", size: 40))
                        .foregroundColor(getSubtitleColor())
                }
            }
        }
    }
    
    private func getSubtitleColor() -> Color {
        // High Contrast Blue/Teal (Matches SplashView)
        return Color.themeBlue
    }
}

#Preview {
    SudokuLogoTitleView()
}
