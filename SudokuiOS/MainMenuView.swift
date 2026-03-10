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
        case customGame(CustomSudokuLevel, session: GameSession?)
        case game(Int, session: GameSession?)
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
                                    
                                    if isCustom {
                                        let customLevelID = session.customLevelId ?? lastCustomLevelUUID
                                        if let customLevel = customLevels.first(where: { $0.id.uuidString == customLevelID }) {
                                            Button(action: {
                                                navigationPath = [.customGame(customLevel, session: session)]
                                            }) {
                                                continueCardContent(
                                                    title: customLevel.levelName,
                                                    iconName: customLevel.ruleType.iconName,
                                                    ruleName: customLevel.ruleType.shortName,
                                                    timeElapsed: session.timeElapsed
                                                )
                                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    } else {
                                        let level = viewModel.levels.first(where: { $0.id == session.levelID })
                                        Button(action: {
                                            navigationPath = [.game(session.levelID, session: session)]
                                        }) {
                                            continueCardContent(
                                                title: "Level \(session.levelID)",
                                                iconName: level?.ruleType.iconName ?? "square.grid.3x3",
                                                ruleName: level?.ruleType.displayName ?? "Sudoku",
                                                timeElapsed: session.timeElapsed
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                        }
                                        .buttonStyle(.plain)
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
                case .customGame(let level, let session):
                    CustomGameWrapperView(
                        customLevel: level,
                        viewModel: viewModel,
                        adCoordinator: adCoordinator,
                        navigationStack: $navigationPath,
                        session: session
                    )
                case .game(let id, let session):
                     SudokuGameView(levelID: id, viewModel: viewModel, adCoordinator: adCoordinator, session: session, onNextLevel: { targetID in
                         print("MainMenuView: traversing to next level \(targetID) from \(id)")
                         // Defer navigation to allow Ad dismissal to fully complete and view hierarchy to stabilize
                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                             if !navigationPath.isEmpty {
                                 navigationPath[navigationPath.count - 1] = .game(targetID, session: nil)
                             } else {
                                 navigationPath.append(.game(targetID, session: nil))
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
        let lastPlayedMode = UserDefaults.standard.string(forKey: "lastPlayedMode") ?? "standard"
        
        if lastPlayedMode == "custom" {
            if let customLevel = customLevels.first(where: { $0.id.uuidString == lastCustomLevelUUID }),
               customLevel.savedBoardProgress != nil {
                // Return a "Skeleton" session to satisfy the UI, although we could also 
                // refactor the UI to check both. For now, feeding a minimal session is safest.
                var session = GameSession(
                    levelID: -1, // Not used for custom
                    isCustomLevel: true,
                    customLevelId: lastCustomLevelUUID
                )
                session.userBoard = customLevel.savedBoardProgress
                session.timeElapsed = customLevel.savedTime
                session.notesData = customLevel.savedNotesData
                session.colorData = customLevel.savedColorData
                session.markedCombinationsData = customLevel.savedMarkedCombinationsData
                session.killerMarkedCombinationsData = customLevel.savedKillerMarkedCombinationsData
                session.crossData = customLevel.savedCrossData
                self.activeSession = session
            } else if let data = UserDefaults.standard.data(forKey: "active_custom_session"),
                      let session = try? JSONDecoder().decode(GameSession.self, from: data) {
                self.activeSession = session
            }
        } else {
            // Standard fallback
            if let data = UserDefaults.standard.data(forKey: "active_standard_session"),
               let session = try? JSONDecoder().decode(GameSession.self, from: data) {
                self.activeSession = session
            } else if let data = UserDefaults.standard.data(forKey: "activeGameSession"), // FINAL LEGACY FALLBACK
                      let session = try? JSONDecoder().decode(GameSession.self, from: data) {
                self.activeSession = session
            }
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
