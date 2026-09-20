import Foundation
import Observation

/// Tracks the user's in-app language override (AppSettings.appLanguage), independent of the
/// device's system language. SwiftUI `Text("...")` calls pick this up automatically via
/// `.environment(\.locale, ...)` applied at the app root (see SudokuiOSApp.swift) — that alone
/// is enough for the vast majority of the app's UI text.
///
/// It does NOT cover `String(localized:)` calls made outside the SwiftUI view hierarchy (in
/// ViewModels/Models — e.g. SudokuRuleType.displayName, AppSettings' enum `.text` properties,
/// SudokuGameViewModel.hintErrorMessage), since those aren't inside any view's environment and
/// default to the device's locale. Those call sites use `localized(_:)` below instead of bare
/// `String(localized:)`, so they respect the in-app override too.
///
/// This MUST be `@Observable` (Swift's Observation framework), not a plain `static var`. A plain
/// static var change is invisible to SwiftUI's dependency tracking, so any view whose body reads
/// a `localized(_:)`-derived value (rule names, filter names, "Level N" titles, etc.) would keep
/// showing stale text until something else forced that view to re-render — which is exactly the
/// bug this fixes (Filter names, the Main Menu "Continue" card's level title, and rule/variant
/// names like "Knight"/"Classic" everywhere they're shown, weren't updating live). `@Observable`
/// tracks property access through arbitrarily deep call chains, not just direct property-wrapper
/// usage — so as long as `localized(_:)` is reached synchronously during a view's `body`
/// evaluation (even nested many calls deep through a model's computed property), SwiftUI
/// correctly detects the dependency and re-renders that view when the language changes, with no
/// need to manually wire every affected view.
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()
    private init() {}

    /// Updated whenever AppSettings.appLanguage changes (see AppSettings.swift's `appLanguage`
    /// setter) and once at launch from the persisted value (see SudokuiOSApp.init()). Defaults
    /// to the device's current locale until a language override is set.
    var currentLocale: Locale = .autoupdatingCurrent
}

/// Looks up a localized string honoring the current in-app language override. Use this instead
/// of bare `String(localized:)` in any ViewModel/Model code (outside a SwiftUI view's body) so
/// the in-app language switcher (Settings → Language) actually applies to it, and so any view
/// displaying the result updates live when the language changes.
func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, locale: LocalizationManager.shared.currentLocale)
}
