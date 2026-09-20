import Foundation
import Observation

/// Tracks the user's in-app language override (AppSettings.appLanguage), independent of the
/// device's system language. SwiftUI `Text("...")` calls pick this up automatically via
/// `.environment(\.locale, ...)` applied at the app root (see SudokuiOSApp.swift) — that is the
/// primary, and for almost all UI text the *only*, mechanism that actually works. See
/// CLAUDE.md's Localization section for the full history of why: displaying ViewModel/Model
/// text used to go through this class's `localized(_:)` helper, which turned out not to reliably
/// honor a non-default locale override at all (regardless of how reactively it was wired) — that
/// approach was abandoned in favor of routing every display site through `LocalizedStringKey`
/// instead, which resolves against `.environment(\.locale)` like any literal `Text(...)`.
///
/// `currentLocale` still exists and is kept in sync for the few remaining call sites that can't
/// go through `Text`/`LocalizedStringKey` at all — a UIKit API taking a plain `String`
/// (`SettingsView`'s mail compose subject/body), or a `String` value that needs to be correctly
/// localized once and then persist as plain text (a custom level's default name). Those use
/// `localized(_:)`/`localizedFormat(_:)` below.
@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()
    private init() {}

    /// Updated whenever AppSettings.appLanguage changes (see AppSettings.swift's `appLanguage`
    /// setter) and once at launch from the persisted value (see SudokuiOSApp.init()). Defaults
    /// to the device's current locale until a language override is set.
    var currentLocale: Locale = .autoupdatingCurrent
}

/// Looks up a localized string honoring the current in-app language override.
///
/// NOTE: `String(localized:locale:)` does not reliably honor an explicit non-default `locale:`
/// override in this project (confirmed via a direct A/B test — a literal `Text("Level \(id)")`,
/// resolved via `.environment(\.locale)`, translates correctly; the identical text built via
/// this function never did, regardless of reactivity). As a result this is now used ONLY for the
/// handful of call sites that can't go through `Text`/`LocalizedStringKey` at all (currently:
/// `SettingsView`'s mail subject/body, passed to `MFMailComposeViewController`). Prefer
/// `Text(LocalizedStringKey(...))` for anything SwiftUI actually renders, and
/// `localizedFormat(_:)` below for a plain `String` result needed outside a View — see
/// CLAUDE.md's Localization section for the full explanation.
func localized(_ key: String.LocalizationValue) -> String {
    String(localized: key, locale: LocalizationManager.shared.currentLocale)
}

/// Looks up a format string from the String Catalog via the classic `Bundle.localizedString`
/// (NSLocalizedString-style) lookup, honoring the in-app language override — a different, older
/// code path than `String(localized:locale:)`, used here because that API doesn't reliably
/// respect an explicit non-default locale in this project. `englishKey` is the exact English
/// catalog key (e.g. `"Level %lld"`); pass the result to `String(format:)` with the interpolated
/// arguments. Falls back to the English key itself (which still reads correctly, just
/// untranslated) if the target language's bundle can't be found. Use only where a plain `String`
/// is required outside a SwiftUI view (e.g. a default value pre-filled into an editable text
/// field) — for anything SwiftUI renders, prefer `Text(LocalizedStringKey(...))` instead.
func localizedFormat(_ englishKey: String) -> String {
    let locale = LocalizationManager.shared.currentLocale
    guard let languageCode = locale.language.languageCode?.identifier,
          let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return englishKey
    }
    return bundle.localizedString(forKey: englishKey, value: englishKey, table: "Localizable")
}
