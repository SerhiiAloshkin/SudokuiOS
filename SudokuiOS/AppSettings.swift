import SwiftData
import Foundation
import Observation
import SwiftUI

enum HighlightMode: String, CaseIterable, Codable {
    case restriction = "restriction" // A: Highlights same numbers and 3x3 box
    case potential = "potential"   // B: Highlights valid spots
}

enum MistakeMode: String, CaseIterable, Codable {
    case never = "never"
    case onFull = "onFull"
    case immediate = "immediate"

    // LocalizedStringKey (not String via localized(_:)) — display-only, resolved through
    // SwiftUI's own environment-locale-driven catalog lookup, the only mechanism confirmed to
    // actually track the in-app language switcher.
    var text: LocalizedStringKey {
        switch self {
        case .never: return "Never"
        case .onFull: return "When Board Full"
        case .immediate: return "Immediately"
        }
    }
}

enum HintTarget: String, CaseIterable, Codable {
    case selectedCell = "selectedCell"
    case randomCell = "randomCell"

    var text: LocalizedStringKey {
        switch self {
        case .selectedCell: return "Selected Cell"
        case .randomCell: return "Random Cell"
        }
    }
}

@Model
final class AppSettings {
    var isMinimalHighlight: Bool = false
    var highlightModeRaw: String = "restriction" // Stored as String for SwiftData simplicity
    var isTimerVisible: Bool = true
    // var isSoundEnabled: Bool = false // Sound system removed
    var isHighlightSameNumberEnabled: Bool = true // Default true
    var isHighlightSameNoteEnabled: Bool = true // Default true
    var showMistakes: Bool = true // Deprecated, keeping for migration/fallback
    var mistakeModeRaw: String = "onFull" // Default .onFull
    var hasSeenPotentialWarning: Bool = false
    var hasSeenMultiSelectHighlightNote: Bool = false
    var hasSeenTutorial: Bool = false
    var isDisableCompletedDigitsEnabled: Bool = true
    var isCombinationHelperEnabled: Bool = true
    var isAutoFilterCombinationsEnabled: Bool = false // Default Off
    var hintTargetRaw: String = "selectedCell" // Default Selected Cell
    var appThemeRaw: String = "light" // Default Light
    var languageCodeRaw: String = "system" // Default: follow device language

    init(isMinimalHighlight: Bool = true, highlightMode: HighlightMode = .restriction, isTimerVisible: Bool = true, isHighlightSameNumberEnabled: Bool = true, isHighlightSameNoteEnabled: Bool = true, showMistakes: Bool = true, mistakeMode: MistakeMode = .onFull, hasSeenPotentialWarning: Bool = false, hasSeenMultiSelectHighlightNote: Bool = false, hasSeenTutorial: Bool = false, isDisableCompletedDigitsEnabled: Bool = true, isCombinationHelperEnabled: Bool = true, isAutoFilterCombinationsEnabled: Bool = false, hintTarget: HintTarget = .selectedCell, theme: AppTheme = .light) {
        self.isMinimalHighlight = isMinimalHighlight
        self.highlightModeRaw = highlightMode.rawValue
        self.isTimerVisible = isTimerVisible
        // self.isSoundEnabled = false
        self.isHighlightSameNumberEnabled = isHighlightSameNumberEnabled
        self.isHighlightSameNoteEnabled = isHighlightSameNoteEnabled
        self.showMistakes = showMistakes
        self.mistakeModeRaw = mistakeMode.rawValue
        self.hasSeenPotentialWarning = hasSeenPotentialWarning
        self.hasSeenMultiSelectHighlightNote = hasSeenMultiSelectHighlightNote
        self.hasSeenTutorial = hasSeenTutorial
        self.isDisableCompletedDigitsEnabled = isDisableCompletedDigitsEnabled
        self.isCombinationHelperEnabled = isCombinationHelperEnabled
        self.isAutoFilterCombinationsEnabled = isAutoFilterCombinationsEnabled
        self.hintTargetRaw = hintTarget.rawValue
        self.appThemeRaw = theme.rawValue
    }
    
    // Bridge to UserDefaults for Hint Targeting
    var hintAppliesToSelectedCell: Bool {
        get { UserDefaults.standard.bool(forKey: "hintAppliesToSelectedCell") }
        set { UserDefaults.standard.set(newValue, forKey: "hintAppliesToSelectedCell") }
    }
    
    // Bridge to UserDefaults for Persistent Hint Cooldown
    var nextHintAvailableDate: Date? {
        get { UserDefaults.standard.object(forKey: "nextHintAvailableDate") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "nextHintAvailableDate") }
    }
    
    // Bridge to UserDefaults for Mistake Limit
    var isMistakeLimitEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "isMistakeLimitEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "isMistakeLimitEnabled") }
    }
    
    // Bridge to UserDefaults for Show Hint Button
    var showHintButton: Bool {
        get { UserDefaults.standard.object(forKey: "showHintButton") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "showHintButton") }
    }
    
    var highlightMode: HighlightMode {
        get { HighlightMode(rawValue: highlightModeRaw) ?? .restriction }
        set { highlightModeRaw = newValue.rawValue }
    }
    
    var mistakeMode: MistakeMode {
        get { MistakeMode(rawValue: mistakeModeRaw) ?? .onFull }
        set { mistakeModeRaw = newValue.rawValue }
    }
    
    var hintTarget: HintTarget {
        get { HintTarget(rawValue: hintTargetRaw) ?? .selectedCell }
        set { 
            hintTargetRaw = newValue.rawValue
            // Sync to legacy UserDefaults for ViewModel access
            UserDefaults.standard.set(newValue == .selectedCell, forKey: "hintAppliesToSelectedCell")
        }
    }
    
    var appTheme: AppTheme {
        get { AppTheme(rawValue: appThemeRaw) ?? .light }
        set { appThemeRaw = newValue.rawValue }
    }

    var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: languageCodeRaw) ?? .system }
        set {
            languageCodeRaw = newValue.rawValue
            // Keep the ViewModel/Model-layer localized(_:) helper in sync immediately, so a
            // language change applies right away rather than only on next launch.
            LocalizationManager.shared.currentLocale = newValue.locale ?? .autoupdatingCurrent
        }
    }
}

enum AppTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var text: LocalizedStringKey {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum AppLanguage: String, CaseIterable, Codable {
    case system = "system"
    case english = "en"
    case french = "fr"
    case ukrainian = "uk"

    // Each language's own name, shown in ITS OWN language (standard convention for language
    // pickers) — deliberately NOT translated, since these labels shouldn't change when the
    // app's language changes. "System" is the one exception and still resolves through
    // LocalizedStringKey (not localized(_:) — see SudokuRuleType.displayName's comment).
    var text: LocalizedStringKey {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .french: return "Français"
        case .ukrainian: return "Українська"
        }
    }

    /// nil means "follow the device's system language."
    var locale: Locale? {
        switch self {
        case .system: return nil
        case .english, .french, .ukrainian: return Locale(identifier: rawValue)
        }
    }
}
