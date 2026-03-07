import SwiftUI

struct NumberPadView: View {
    var completedDigits: Set<Int>
    var isSandwich: Bool = false
    
    // Action closure: passes the number tapped (1-9), or 0 for clear/delete
    var action: (Int) -> Void
    var action19: (() -> Void)? = nil
    
    // Config
    private let spacing: CGFloat = 4
    private let horizontalMargin: CGFloat = 4
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            // Total Margin (Leading + Trailing) - assuming parent might have padding, 
            // but we use available width. We can deduct a small margin if we want internal spacing.
            // Let's deduct same margin as before to be safe if it's edge-to-edge.
            let totalMargin = horizontalMargin * 2
            let buttonCount: CGFloat = isSandwich ? 10.0 : 9.0
            let totalSpacing = spacing * (buttonCount - 1)
            
            let buttonSize = (width - totalMargin - totalSpacing) / buttonCount
            let safeButtonSize = max(0, buttonSize)
            
            HStack(spacing: spacing) {
                ForEach(1...9, id: \.self) { number in
                    NumberButton(number: number, isCompleted: completedDigits.contains(number), size: safeButtonSize) {
                        action(number)
                    }
                }
                
                if isSandwich {
                    Button19(size: safeButtonSize) {
                        action19?()
                    }
                }
            }
            .frame(width: width, alignment: .center)
        }
        .frame(height: 50) // Constrain height to avoid expansion
    }
}

struct NumberButton: View {
    let number: Int
    let isCompleted: Bool
    let size: CGFloat
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.system(size: size * 0.6, weight: .bold, design: .rounded)) // Dynamic font size
                .minimumScaleFactor(0.5)
                .foregroundColor(.blue)
                .frame(width: size, height: size)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(size * 0.2) // Proportional corner radius
        }
        .buttonStyle(ScaleButtonStyle())
        .opacity(isCompleted ? 0.3 : 1.0)
        .disabled(isCompleted)
    }
}

// Custom ButtonStyle for feedback animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct Button19: View {
    let size: CGFloat
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text("19")
                .font(.system(size: size * 0.45, weight: .bold, design: .rounded)) // Smaller font for 19
                .minimumScaleFactor(0.5)
                .foregroundColor(.blue)
                .frame(width: size, height: size)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(size * 0.2) // Proportional corner radius
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
