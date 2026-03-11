import SwiftUI

struct PrimaryVersaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.themeBlue)
            .cornerRadius(16)
            .shadow(color: Color.themeBlue.opacity(0.3), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.interactiveSpring(), value: configuration.isPressed)
    }
}

struct SecondaryVersaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundColor(.themeBlue)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.themeBlue.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.interactiveSpring(), value: configuration.isPressed)
    }
}

struct UtilityVersaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .foregroundColor(.themeBlue)
            .frame(width: 56, height: 56)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.themeBlue.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.interactiveSpring(), value: configuration.isPressed)
    }
}

/// A general-purpose rounded button style used for in-game actions
struct VersaButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(isEnabled ? .primary : .secondary.opacity(0.5))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isEnabled ? Color.themeBlue.opacity(0.15) : Color.gray.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isEnabled ? Color.themeBlue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
