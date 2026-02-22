import SwiftData
import SwiftUI
import GoogleMobileAds
import AdSupport
import AppTrackingTransparency

@main
struct SudokuiOSApp: App {
    // 1. Initialize ModelContainer
    let container: ModelContainer
    
    // 2. Create ViewModel (StateObject ensures it lives as long as the app)
    @StateObject private var levelViewModel: LevelViewModel
    @State private var appSettings: AppSettings?
    @Environment(\.scenePhase) private var scenePhase
    
    // Splash Screen State
    @State private var isSplashActive = true
    
    init() {
        do {
            let schema = Schema([
                UserLevelProgress.self,
                MoveHistory.self,
                AppSettings.self
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
            
            _levelViewModel = StateObject(wrappedValue: LevelViewModel(modelContext: modelContainer.mainContext))
            
            // iCloud Sync Disabled
            // CloudStorageManager.shared.start()
            
            // Initialize AdMob with G-rated configuration
            let config = MobileAds.shared.requestConfiguration
            config.maxAdContentRating = GADMaxAdContentRating.general
            
            MobileAds.shared.start(completionHandler: nil)
            
            // Log IDFA for Test Device Registration
            // Note: In production, tracking authorization must be requested first.
            // For testing/debugging, we can log the identifier if available or zeros.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                 let idfa = ASIdentifierManager.shared().advertisingIdentifier
                 print("YOUR_Nexus_6_Device_ID: \(idfa.uuidString)") // Label for easy grep
                 print("AdMob Test Device ID: \(idfa.uuidString)")
            }
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if isSplashActive {
                    SplashView(isActive: $isSplashActive)
                } else {
                    MainMenuView()
                }
            }
            .environmentObject(levelViewModel)
            .environment(appSettings) // Inject AppSettings
            .preferredColorScheme(appSettings?.appTheme.colorScheme) // Adaptive Theme
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
