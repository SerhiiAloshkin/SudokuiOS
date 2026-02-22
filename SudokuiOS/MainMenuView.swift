import SwiftUI
import SwiftData

struct MainMenuView: View {
    @EnvironmentObject var viewModel: LevelViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) var settings
    @AppStorage("lastUnfinishedLevelID") private var lastUnfinishedLevelID: Int = -1
    @AppStorage("lastPlayedTimestamp") private var lastPlayedTimestamp: Double = 0.0
    @State private var showSettings = false
    @State private var navigationPath: [SudokuRoute] = []
    @StateObject private var adCoordinator = AdCoordinator() // Manage Ads Globally/at Menu Level
    
    enum SudokuRoute: Hashable {
        case levelSelection
        case game(Int)
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                ZStack {
                    // 1. Background Flavor
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                    
                    // Floating Icons (Decorative)
                    VStack {
                        HStack {
                            Image(systemName: "square.grid.3x3.fill")
                                .font(.system(size: 80))
                                .foregroundColor(Color.themeBlue.opacity(0.05))
                                .rotationEffect(.degrees(-15))
                                .offset(x: -20, y: -20)
                            Spacer()
                            Image(systemName: "crown.fill")
                                .font(.system(size: 60))
                                .foregroundColor(Color.themeBlue.opacity(0.05))
                                .rotationEffect(.degrees(20))
                                .offset(x: 20, y: 10)
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "thermometer")
                                .font(.system(size: 100))
                                .foregroundColor(Color.themeBlue.opacity(0.05))
                                .rotationEffect(.degrees(-10))
                                .offset(x: 30, y: 30)
                        }
                    }
                    .ignoresSafeArea()
                    
                    // 2. Main Content
                    VStack(spacing: 0) {
                        // Upper Third: Title
                        Spacer(minLength: 40)
                        
                        SudokuLogoTitleView()
                            .transition(.move(edge: .top).combined(with: .opacity))
                        
                        // Weighted Spacer (Push content up)
                        Spacer()
                        
                        // Button Stack (Upper Two-Thirds)
                        if showButtons {
                            VStack(spacing: 20) {
                                // 1. Continue Level (Dynamic Card)
                                if lastUnfinishedLevelID != -1, let level = viewModel.levels.first(where: { $0.id == lastUnfinishedLevelID }) {
                                     Button(action: {
                                         navigationPath = [.levelSelection, .game(lastUnfinishedLevelID)]
                                     }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("CONTINUE")
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white.opacity(0.8))
                                                    .tracking(1)
                                                
                                                Text("Level \(lastUnfinishedLevelID)")
                                                    .font(.title)
                                                    .fontWeight(.black)
                                                    .foregroundColor(.white)
                                                
                                                HStack(spacing: 6) {
                                                    Image(systemName: level.ruleType.iconName) // Dynamic Icon
                                                        .font(.caption)
                                                    Text(level.ruleType.displayName)
                                                        .font(.caption)
                                                    
                                                    Text("•")
                                                    Text(formatTime(seconds: level.timeElapsed))
                                                        .font(.caption)
                                                        .monospacedDigit()
                                                }
                                                .foregroundColor(.white.opacity(0.9))
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "play.circle.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.white)
                                        }
                                        .padding()
                                        .background(
                                            ZStack {
                                                Color.themeBlue // Base Brand Color
                                                // Simple Grid Overlay
                                                LevelGridPattern()
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            }
                                        )
                                        .cornerRadius(16)
                                        .shadow(color: Color.themeBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                                    }
                                    .buttonStyle(PlainButtonStyle()) // Custom card style
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                                
                                // 2. Select Level (Primary Action)
                                Button(action: {
                                    navigationPath.append(.levelSelection)
                                }) {
                                    HStack {
                                        Image(systemName: "square.grid.2x2.fill")
                                        Text("Select Level")
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                
                                // 3. Settings (Secondary Action)
                                Button(action: {
                                    showSettings = true
                                }) {
                                    HStack {
                                        Image(systemName: "gearshape")
                                        Text("Settings")
                                    }
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            .padding(.horizontal, 30)
                        }
                        
                        // Push Ad to Bottom (Removed)
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: SudokuRoute.self) { route in
                switch route {
                case .levelSelection:
                    LevelSelectionView(navigationStack: $navigationPath)
                case .game(let id):
                     SudokuGameView(levelID: id, viewModel: viewModel, adCoordinator: adCoordinator, onNextLevel: { targetID in
                         print("MainMenuView: traversing to next level \(targetID) from \(id)")
                         // Defer navigation to allow Ad dismissal to fully complete and view hierarchy to stabilize
                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                             if !navigationPath.isEmpty {
                                 navigationPath[navigationPath.count - 1] = .game(targetID)
                             } else {
                                 navigationPath.append(.game(targetID))
                             }
                         }
                     })
                     .id(id) // Force recreation of StateObject when ID changes
                }
            }
            .onAppear {
                // crucial: inject context if not already done, and reload
                if viewModel.modelContext == nil {
                    viewModel.updateContext(modelContext)
                } else {
                    viewModel.loadProgressFromSwiftData()
                }
                
                // Animation Logic
                if !showButtons {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showButtons = true
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(settings: settings)
            }
            .onChange(of: showSettings) { _, newValue in
                if !newValue {
                    viewModel.refreshLevelState()
                }
            }
        }
    }
    
    @State private var showButtons = false
    
    private func formatTime(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct MainMenuView_Previews: PreviewProvider {
    static var previews: some View {
        MainMenuView()
            .environmentObject(LevelViewModel())
    }
}
