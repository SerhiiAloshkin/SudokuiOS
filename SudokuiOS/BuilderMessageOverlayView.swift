import SwiftUI

struct BuilderMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let footnote: String?
    var buttonTitle: String = "OK"
}

struct BuilderMessageOverlayView: View {
    let title: String
    let message: String
    let footnote: String?
    var buttonTitle: String = "OK"
    let action: () -> Void
    
    @State private var animateIn = false
    
    var body: some View {
        ZStack {
            // Blurred background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal by tapping outside to ensure user reads disclaimer
                }
            
            VStack(spacing: 24) {
                // Title
                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Message
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                    .padding(.horizontal)
                
                if let footnote = footnote {
                    Divider()
                        .padding(.horizontal)
                    
                    // Disclaimer Footnote
                    Text(footnote)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Action Button
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 30)
            .scaleEffect(animateIn ? 1.0 : 0.8)
            .opacity(animateIn ? 1.0 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                animateIn = true
            }
        }
    }
}

#Preview {
    BuilderMessageOverlayView(
        title: "Success",
        message: "Level saved successfully!",
        footnote: "Note: Automated verification can make mistakes or might not cover all logical paths a human can.",
        action: {}
    )
}
