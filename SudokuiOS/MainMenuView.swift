import SwiftUI
import SwiftData

struct MainMenuView: View {
    @EnvironmentObject var viewModel: LevelViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) var settings
    @AppStorage("lastUnfinishedLevelID") private var lastUnfinishedLevelID: Int = -1
    @AppStorage("lastPlayedTimestamp") private var lastPlayedTimestamp: Double = 0.0
    @AppStorage("lastCustomLevelUUID") private var lastCustomLevelUUID: String = ""
    @Query private var customLevels: [CustomSudokuLevel]
    @State private var showSettings = false
    @State private var navigationPath: [SudokuRoute] = []
    @StateObject private var adCoordinator = AdCoordinator() // Manage Ads Globally/at Menu Level
    @State private var activeSession: GameSession? = nil
    @State private var showButtons = false
    
    enum SudokuRoute: Hashable {
        case levelSelection
        case levelBuilder
        case levelBuilderEdit(CustomSudokuLevel)
        case customLevels
        case customGame(CustomSudokuLevel)
        case game(Int)
        
        // Hashable conformance for CustomSudokuLevel
        static func == (lhs: SudokuRoute, rhs: SudokuRoute) -> Bool {
            switch (lhs, rhs) {
            case (.levelSelection, .levelSelection): return true
            case (.levelBuilder, .levelBuilder): return true
            case (.levelBuilderEdit(let a), .levelBuilderEdit(let b)): return a.id == b.id
            case (.customLevels, .customLevels): return true
            case (.customGame(let a), .customGame(let b)): return a.id == b.id
            case (.game(let a), .game(let b)): return a == b
            default: return false
            }
        }
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .levelSelection: hasher.combine("levelSelection")
            case .levelBuilder: hasher.combine("levelBuilder")
            case .levelBuilderEdit(let level): hasher.combine("levelBuilderEdit"); hasher.combine(level.id)
            case .customLevels: hasher.combine("customLevels")
            case .customGame(let level): hasher.combine("customGame"); hasher.combine(level.id)
            case .game(let id): hasher.combine("game"); hasher.combine(id)
            }
        }
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
                                if let session = activeSession ?? legacySession() {
                                    // Determine if it's a custom level or standard level
                                    let isCustom = session.isCustomLevel
                                    let customLevel = isCustom ? customLevels.first(where: { $0.id.uuidString == session.customLevelId }) : nil
                                    let standardLevel = !isCustom ? viewModel.levels.first(where: { $0.id == session.levelID }) : nil
                                    
                                    if isCustom, let cl = customLevel {
                                        // Custom level Continue
                                        Button(action: {
                                            navigationPath = [.customLevels, .customGame(cl)]
                                        }) {
                                            continueCardContent(
                                                title: cl.levelName,
                                                iconName: cl.ruleType.iconName,
                                                ruleName: cl.ruleType.shortName,
                                                timeElapsed: viewModel.getProgress(for: cl.toSudokuLevel().id)?.timeElapsed ?? 0
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                        }
                                        .buttonStyle(.plain)
                                    } else if !isCustom {
                                        let levelID = session.levelID
                                        let level = standardLevel // Might be nil if levels not loaded yet
                                        
                                        Button(action: {
                                            navigationPath = [.levelSelection, .game(levelID)]
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("CONTINUE")
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.white.opacity(0.8))
                                                        .tracking(1)
                                                    
                                                    Text("Level \(levelID)")
                                                        .font(.title)
                                                        .fontWeight(.black)
                                                        .foregroundColor(.white)
                                                    
                                                    HStack(spacing: 6) {
                                                        Image(systemName: level?.ruleType.iconName ?? "square.grid.3x3")
                                                            .font(.caption)
                                                        Text(level?.ruleType.displayName ?? "Sudoku")
                                                            .font(.caption)
                                                        
                                                        let time = level?.timeElapsed ?? 0
                                                        if time > 0 {
                                                            Text("•")
                                                            Text(formatTime(seconds: time))
                                                                .font(.caption)
                                                                .monospacedDigit()
                                                        }
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
                                                    Color.themeBlue
                                                    LevelGridPattern()
                                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                                }
                                            )
                                            .cornerRadius(16)
                                            .shadow(color: Color.themeBlue.opacity(0.3), radius: 8, x: 0, y: 4)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                    }
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
                                
                                // 2.5 Level Builder (Primary Action)
                                Button(action: {
                                    navigationPath.append(.levelBuilder)
                                }) {
                                    HStack {
                                        Image(systemName: "hammer.fill")
                                        Text("Level Builder")
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                
                                // 2.6 My Levels
                                Button(action: {
                                    navigationPath.append(.customLevels)
                                }) {
                                    HStack {
                                        Image(systemName: "tray.full.fill")
                                        Text("My Levels")
                                    }
                                }
                                .buttonStyle(SecondaryButtonStyle())
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
                case .levelBuilder:
                    LevelBuilderView(navigationStack: $navigationPath)
                case .levelBuilderEdit(let level):
                    LevelBuilderView(navigationStack: $navigationPath, existingLevel: level)
                case .customLevels:
                    CustomLevelsListView(navigationStack: $navigationPath)
                case .customGame(let customLevel):
                    CustomGameWrapperView(
                        customLevel: customLevel,
                        viewModel: viewModel,
                        adCoordinator: adCoordinator,
                        navigationStack: $navigationPath
                    )
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
                
                // Load levels if empty (needed for Continue button metadata)
                if viewModel.levels.isEmpty {
                    viewModel.loadLevelsFromJSON()
                }
                
                loadSession()
                
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
    
    private func formatTime(seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    private func continueCardContent(title: String, iconName: String, ruleName: String, timeElapsed: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("CONTINUE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.8))
                    .tracking(1)
                
                Text(title)
                    .font(.title)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                
                HStack(spacing: 6) {
                    Image(systemName: iconName)
                        .font(.caption)
                    Text(ruleName)
                        .font(.caption)
                    
                    if timeElapsed > 0 {
                        Text("•")
                        Text(formatTime(seconds: timeElapsed))
                            .font(.caption)
                            .monospacedDigit()
                    }
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
                Color.themeBlue
                LevelGridPattern()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
        )
        .cornerRadius(16)
        .shadow(color: Color.themeBlue.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    private func loadSession() {
        if let data = UserDefaults.standard.data(forKey: "activeGameSession"),
           let session = try? JSONDecoder().decode(GameSession.self, from: data) {
            self.activeSession = session
        }
    }
    
    /// Fallback for legacy appstorage-only persistence
    private func legacySession() -> GameSession? {
        guard lastUnfinishedLevelID != -1 else { return nil }
        return GameSession(
            levelID: lastUnfinishedLevelID,
            isCustomLevel: lastUnfinishedLevelID < 0,
            customLevelId: lastCustomLevelUUID,
            timestamp: lastPlayedTimestamp
        )
    }
}

struct MainMenuView_Previews: PreviewProvider {
    static var previews: some View {
        MainMenuView()
            .environmentObject(LevelViewModel())
    }
}
