import SwiftData
import SwiftUI

@main
struct SudokuiOSApp: App {
    // 1. Initialize ModelContainer
    let container: ModelContainer
    
    // 2. Create ViewModel (StateObject ensures it lives as long as the app)
    @StateObject private var levelViewModel: LevelViewModel
    @State private var appSettings: AppSettings?
    @Environment(\.scenePhase) private var scenePhase
    
    // Splash Screen State handled by LevelViewModel.ensureLevelsLoaded() lazily
    
    init() {
        do {
            let schema = Schema([
                UserLevelProgress.self,
                MoveHistory.self,
                AppSettings.self,
                CustomSudokuLevel.self // New Level Builder Model
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.container = modelContainer
            
            // Singleton AppSettings
            let context = modelContainer.mainContext
            let descriptor = FetchDescriptor<AppSettings>()
            let existingSettings = try? context.fetch(descriptor).first
            
            let finalSettings: AppSettings
            if let existing = existingSettings {
                finalSettings = existing
            } else {
                let defaultSettings = AppSettings()
                context.insert(defaultSettings)
                try? context.save()
                finalSettings = defaultSettings
            }
            
            _appSettings = State(initialValue: finalSettings)

            // SwiftData loads finalSettings.languageCodeRaw directly (not through the
            // appLanguage computed property's setter), so LocalizationManager needs an
            // explicit initial sync here — otherwise a previously-chosen language wouldn't
            // apply to ViewModel/Model-layer localized(_:) strings until the setting was
            // changed again.
            LocalizationManager.shared.currentLocale = finalSettings.appLanguage.locale ?? .autoupdatingCurrent

            _levelViewModel = StateObject(wrappedValue: LevelViewModel(modelContext: modelContainer.mainContext))
            
            // iCloud Sync Disabled
            // CloudStorageManager.shared.start()
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if levelViewModel.appIsReady {
                    MainMenuView()
                        .environmentObject(levelViewModel)
                        .transition(.opacity)
                } else {
                    SplashView(isActive: .constant(true))
                        .environmentObject(levelViewModel)
                }
            }
            .animation(.easeInOut(duration: 0.5), value: levelViewModel.appIsReady)
            .environment(appSettings) // Inject AppSettings
            .preferredColorScheme(appSettings?.appTheme.colorScheme) // Adaptive Theme
            .environment(\.locale, appSettings?.appLanguage.locale ?? .autoupdatingCurrent) // In-app language override
            .modelContainer(container) // Inject for @Query if needed later
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                print("App Backgrounding: Saving All State...")
                try? container.mainContext.save()
            }
        }
    }
}

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
