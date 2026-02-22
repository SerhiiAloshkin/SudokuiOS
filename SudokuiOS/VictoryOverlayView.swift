import SwiftUI

struct VictoryOverlayView: View {
    // Inputs
    let timeElapsed: String
    let currentLevelID: Int
    let nextLevelID: Int
    let nextLevelVariant: SudokuRuleType
    @ObservedObject var adCoordinator: AdCoordinator // Injected Dependency
    let onNextLevel: () -> Void
    let onDismiss: () -> Void
    
    // Animation State
    @State private var showContent = false
    @State private var scale: CGFloat = 0.8
    @State private var praiseWord: String = "Masterful!"
    @State private var isAnimating = false
    @State private var isNavigating = false // Prevent double-taps
    
    private let praiseWords = [
        "Masterful!", "Brilliant!", "Splendid!", "Excellent!", 
        "Fantastic!", "Superb!", "Outstanding!", "Genius!", 
        "Perfect!", "Amazing!"
    ]
    
    var body: some View {
        ZStack {
            // 1. Blurred Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    // Optional: Tap outside to dismiss? Or force button interaction?
                    // Let's keep it modal to ensure intention
                }
            
            VStack(spacing: 30) {
                // 2. Title "Masterful!"
                Text(praiseWord)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                
                // 3. Time Stat
                HStack(spacing: 8) {
                    Image(systemName: "stopwatch.fill")
                        .foregroundColor(.secondary)
                    Text(timeElapsed)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)
                
                // 4. Next Level Preview
                VStack(spacing: 12) {
                    HStack(spacing: 15) {
                        // Variant Icon
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 50, height: 50)
                            
                            variantIcon
                                .foregroundColor(.green)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next Challenge")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text("Level \(nextLevelID)")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text(nextLevelVariant.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)
                
                // 5. Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        guard !isNavigating else { return }
                        isNavigating = true
                        
                        // Trigger Ad, then Navigate
                        adCoordinator.showInterstitialAd {
                            onNextLevel()
                        }
                    }) {
                        HStack {
                            if nextLevelID > currentLevelID {
                                Text("Next Level")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Image(systemName: "arrow.right.circle.fill")
                            } else {
                                // Backward Navigation (Gap Filling)
                                if currentLevelID == 250 {
                                    // Gate Logic: Explicitly show "Complete Level X"
                                    Text("Complete Level \(nextLevelID)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Image(systemName: "exclamationmark.circle.fill")
                                } else {
                                    Text("Back to Level \(nextLevelID)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                    .disabled(isNavigating)
                    
                    Button(action: onDismiss) {
                        Text("Back to Grid")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 10)
            }
            .padding(40)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 20)
            .scaleEffect(scale)
            .opacity(showContent ? 1 : 0)
        }
        .onAppear {
            if let randomPraise = praiseWords.randomElement() {
                praiseWord = randomPraise
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showContent = true
                scale = 1.0
            }
        }
    }

    // MARK: - Variant Icon Logic
    @ViewBuilder
    private var variantIcon: some View {
        switch nextLevelVariant {
        case .classic:
            Image(systemName: "square.grid.3x3.fill")
                .font(.title)
        case .sandwich:
            Image(systemName: "square.stack.3d.up")
                .font(.title)
        case .arrow:
            Image(systemName: "arrow.up.forward.circle")
                .font(.title)
        case .thermo:
            Image(systemName: "thermometer")
                .font(.title)
        case .killer:
            Image(systemName: "square.dashed")
                .font(.title)
        case .nonConsecutive:
            Image(systemName: "squareshape.split.2x2")
                .font(.title)
            
        case .kropki:
            HStack(spacing: 2) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 14))
                Image(systemName: "circle")
                    .font(.system(size: 14))
            }
            
        case .oddEven:
            HStack(spacing: 2) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Image(systemName: "square.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
        case .knight:
            Image("knight_icon")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 30, height: 30)
                
        case .king:
            Image(systemName: "crown.fill")
                .font(.title)
        }
    }
}

#Preview {
    VictoryOverlayView(
        timeElapsed: "04:20",
        currentLevelID: 14,
        nextLevelID: 15,
        nextLevelVariant: .oddEven,
        adCoordinator: AdCoordinator(), // Mock
        onNextLevel: {},
        onDismiss: {}
    )
}
