import SwiftUI

struct SplashView: View {
    // 1. Control State
    @State private var logoOpacity = 0.0
    @State private var logoScale: CGFloat = 0.8
    @State private var titleOpacity = 0.0
    @State private var titleOffset: CGFloat = 20
    @State private var subtitleColors: [Color] = [.gray, .gray, .gray, .gray, .gray] // Initially hidden/gray
    @State private var subtitleOpacities: [Double] = [0, 0, 0, 0, 0]
    @State private var progress: CGFloat = 0.0
    
    // Binding to toggle Main Menu (Keep for compatibility if used by other views, but we use appIsReady)
    @Binding var isActive: Bool
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var levelViewModel: LevelViewModel // Inject VM for pre-loading
    @Environment(\.modelContext) var modelContext // Inject Context
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background: Light Blue #BEE3F8 (R:190, G:227, B:248)
                Color(red: 190/255, green: 227/255, blue: 248/255)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 1. Logo
                    Image("Logo") // Assumes "Logo" asset exists
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * 0.45, height: geometry.size.width * 0.45)
                        .clipShape(RoundedRectangle(cornerRadius: 30)) // Soften edges like App Icon
                        .opacity(logoOpacity)
                        .scaleEffect(logoScale)
                    
                    VStack(spacing: 5) {
                        // 2. "SUDOKU" (Uppercase)
                        Text("SUDOKU")
                            .font(.custom("AvenirNext-Bold", size: 40))
                            .foregroundColor(.black) // Force black for contrast on light background
                            .opacity(titleOpacity)
                            .offset(y: titleOffset)
                        
                        // 3. "VERSA" (Uppercase, Letter-by-Letter)
                        HStack(spacing: 2) {
                            ForEach(0..<5) { index in
                                Text(String("VERSA"[index]))
                                    .font(.custom("AvenirNext-Bold", size: 40))
                                    .foregroundColor(getSubtitleColor())
                                    .opacity(subtitleOpacities[index])
                            }
                        }
                    }
                    
                    // 4. Custom "Versa Style" Progress Bar
                    VStack(spacing: 8) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.05))
                                .frame(width: 200, height: 6)
                            
                            Capsule()
                                .fill(getSubtitleColor())
                                .frame(width: 200 * progress, height: 6)
                        }
                        
                        Text("Loading Levels...")
                            .font(.custom("AvenirNext-Medium", size: 12))
                            .foregroundColor(getSubtitleColor().opacity(0.6))
                    }
                    .padding(.top, 20)
                    .opacity(titleOpacity) // Sync with title fade-in
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Center content
            }
        }
        .task {
            // 1. Start a slow animation simulating a 15-second max load (up to 90%)
            withAnimation(.linear(duration: 15.0)) {
                progress = 0.90
            }

            // 2. Await the actual heavy background parsing
            await levelViewModel.loadLevelsData()

            // 3. Once data is loaded, override the animation to quickly zip to 100%
            withAnimation(.easeOut(duration: 0.5)) {
                progress = 1.0
            }

            // 4. Wait for the zip animation to finish, then transition
            try? await Task.sleep(nanoseconds: 600_000_000)
            
            withAnimation(.easeInOut(duration: 0.5)) {
                levelViewModel.appIsReady = true
            }
        }
        .onAppear {
            // Initialize Logic (While animation plays)
            if levelViewModel.modelContext == nil {
                levelViewModel.updateContext(modelContext)
            } else {
                levelViewModel.loadProgressFromSwiftData()
            }
            
            runAnimationSequence()
        }
    }
    
    // Helper for Vibrant Color
    private func getSubtitleColor() -> Color {
        // High Contrast Blue/Teal on Light Blue Background
        return Color(red: 0/255, green: 100/255, blue: 200/255) // Darker Vibrant Blue
    }
    
    // String subscript helper
    // ... or just hardcode "Versa" characters
}

extension String {
    subscript(i: Int) -> Character {
        return self[index(startIndex, offsetBy: i)]
    }
}

extension SplashView {
    private func runAnimationSequence() {
        // 0.0s: Logo Scales In (Elastic Bounce)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.5, blendDuration: 0)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // 0.5s: "Sudoku" Fades In with Slide
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.8)) {
                titleOpacity = 1.0
                titleOffset = 0
            }
        }
        
        // 1.0s: "Versa" Fades In (Letter-by-Letter)
        // Stagger each letter by 0.1s
        let baseDelay = 1.0
        for i in 0..<5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + (Double(i) * 0.1)) {
                withAnimation(.easeOut(duration: 0.4)) {
                    subtitleOpacities[i] = 1.0
                }
            }
        }
        
        /* Transition is now handled by direct navigation or local state in SudokuiOSApp */
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView(isActive: .constant(true))
    }
}
