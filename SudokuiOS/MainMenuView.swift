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
    @State private var showButtons = false
    
    enum SudokuRoute: Hashable {
        case levelSelection
        case levelBuilder
        case levelBuilderEdit(CustomSudokuLevel)
        case customLevels
        case customGame(CustomSudokuLevel, session: GameSession?)
        case game(Int, session: GameSession?)
        case howToPlay
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                ZStack {
                    // 1. Background Flavor
                    Color(uiColor: .systemBackground)
                        .ignoresSafeArea()
                    
                    WatermarkBackgroundView()
                        .ignoresSafeArea()
                    
                    // 2. Main Content
                    VStack(spacing: 0) {
                        // Upper Third: Title
                        Spacer(minLength: 40)
                        
                        SudokuLogoTitleView()
                            .transition(.move(edge: .top).combined(with: .opacity))
                        
                        // Weighted Spacer (Push content up)
                        Spacer()
                        
                        // Button Stack (Center Area)
                        if showButtons {
                            VStack(spacing: 24) {
                                // 1. Continue Level (Primary Card)
                                if let session = viewModel.activeSession {
                                    let isCustom = session.isCustomLevel
                                    
                                    if isCustom {
                                        let lastCustomLevelUUID = UserDefaults.standard.string(forKey: "lastCustomLevelUUID") ?? ""
                                        let customLevelID = session.customLevelId ?? lastCustomLevelUUID
                                        if let customLevel = customLevels.first(where: { $0.id.uuidString == customLevelID }) {
                                            Button(action: {
                                                navigationPath = [.customLevels, .customGame(customLevel, session: session)]
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
                                            // INJECT Level Selection into history so "Back to Grid" works
                                            navigationPath = [.levelSelection, .game(session.levelID, session: session)]
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
                                
                                // 2. Play Campaign (Primary)
                                Button(action: {
                                    navigationPath.append(.levelSelection)
                                }) {
                                    HStack {
                                        Image(systemName: "play.fill")
                                        Text("Play Campaign")
                                    }
                                }
                                .buttonStyle(PrimaryVersaButtonStyle())
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                
                                // 3. Secondary Actions
                                VStack(spacing: 12) {
                                    Button(action: {
                                        navigationPath.append(.levelBuilder)
                                    }) {
                                        HStack {
                                            Image(systemName: "hammer.fill")
                                            Text("Level Builder")
                                        }
                                    }
                                    .buttonStyle(SecondaryVersaButtonStyle())
                                    
                                    Button(action: {
                                        navigationPath.append(.customLevels)
                                    }) {
                                        HStack {
                                            Image(systemName: "tray.full.fill")
                                            Text("My Custom Levels")
                                        }
                                    }
                                    .buttonStyle(SecondaryVersaButtonStyle())
                                }
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                            .padding(.horizontal, 40)
                        }
                        
                        Spacer()
                        
                        // Bottom Utility Bar
                        if showButtons {
                            HStack(spacing: 40) {
                                Button(action: {
                                    navigationPath.append(.howToPlay)
                                }) {
                                    Image(systemName: "book.fill")
                                }
                                .buttonStyle(UtilityVersaButtonStyle())
                                
                                Button(action: {
                                    showSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                }
                                .buttonStyle(UtilityVersaButtonStyle())
                            }
                            .padding(.bottom, 40)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
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
                 case .howToPlay:
                     HowToPlayView()
                 }
            }
            .onAppear {
                // crucial: inject context if not already done, and reload
                if viewModel.modelContext == nil {
                    viewModel.updateContext(modelContext)
                } else {
                    viewModel.loadProgressFromSwiftData()
                }
                
                // Ensure levels are loaded lazily
                viewModel.ensureLevelsLoaded()
                
                viewModel.loadActiveSession()
                
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
}

struct MainMenuView_Previews: PreviewProvider {
    static var previews: some View {
        MainMenuView()
            .environmentObject(LevelViewModel())
    }
}
