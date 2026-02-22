import SwiftData
import Foundation
import Observation

enum HighlightMode: String, CaseIterable, Codable {
    case restriction = "restriction" // A: Highlights same numbers and 3x3 box
    case potential = "potential"   // B: Highlights valid spots
}

enum MistakeMode: String, CaseIterable, Codable {
    case never = "never"
    case onFull = "onFull"
    case immediate = "immediate"
    
    var text: String {
        switch self {
        case .never: return "Never"
        case .onFull: return "When Board Full"
        case .immediate: return "Immediately"
        }
    }
}

@Model
final class AppSettings {
    var isMinimalHighlight: Bool = true
    var highlightModeRaw: String = "restriction" // Stored as String for SwiftData simplicity
    var isTimerVisible: Bool = true
    // var isSoundEnabled: Bool = false // Sound system removed
    var isHighlightSameNumberEnabled: Bool = true // Default true
    var isHighlightSameNoteEnabled: Bool = true // Default true
    var showMistakes: Bool = true // Deprecated, keeping for migration/fallback
    var mistakeModeRaw: String = "onFull" // Default .whenBoardFull
    var hasSeenPotentialWarning: Bool = false
    var hasSeenTutorial: Bool = false
    
    init(isMinimalHighlight: Bool = true, highlightMode: HighlightMode = .restriction, isTimerVisible: Bool = true, isHighlightSameNumberEnabled: Bool = true, isHighlightSameNoteEnabled: Bool = true, showMistakes: Bool = true, mistakeMode: MistakeMode = .onFull, hasSeenPotentialWarning: Bool = false, hasSeenTutorial: Bool = false) {
        self.isMinimalHighlight = isMinimalHighlight
        self.highlightModeRaw = highlightMode.rawValue
        self.isTimerVisible = isTimerVisible
        // self.isSoundEnabled = false
        self.isHighlightSameNumberEnabled = isHighlightSameNumberEnabled
        self.isHighlightSameNoteEnabled = isHighlightSameNoteEnabled
        self.showMistakes = showMistakes
        self.mistakeModeRaw = mistakeMode.rawValue
        self.hasSeenPotentialWarning = hasSeenPotentialWarning
        self.hasSeenTutorial = hasSeenTutorial
    }
    
    // Bridge to UserDefaults for Ad Free Status (User Request)
    var didPurchaseRemoveAds: Bool {
        get { UserDefaults.standard.bool(forKey: "isAdsRemoved") }
        set { UserDefaults.standard.set(newValue, forKey: "isAdsRemoved") }
    }
    
    var highlightMode: HighlightMode {
        get { HighlightMode(rawValue: highlightModeRaw) ?? .restriction }
        set { highlightModeRaw = newValue.rawValue }
    }
    
    var mistakeMode: MistakeMode {
        get { MistakeMode(rawValue: mistakeModeRaw) ?? .immediate }
        set { mistakeModeRaw = newValue.rawValue }
    }
    
    var appThemeRaw: String = "light"
    var appTheme: AppTheme {
        get { AppTheme(rawValue: appThemeRaw) ?? .system }
        set { appThemeRaw = newValue.rawValue }
    }
}

enum AppTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var text: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}
