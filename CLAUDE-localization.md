# Sudoku Game — Localization (English, French, Ukrainian)

Read this before adding or changing any user-facing string. Referenced from `CLAUDE.md`
("Localization") and from comments in `SettingsView.swift` / `LocalizationManager.swift`.

The app supports English (source language), French, and Ukrainian via a single Apple **String
Catalog**: `Localizable.xcstrings` at the project root. Adding a 4th language later means adding
one more `AppLanguage` case (`AppSettings.swift`) plus one more language entry inside the
catalog — nothing else about the source code changes for that.

**There's an in-app language switcher** (Settings → Appearance → Language), independent of the
device's system language — `AppSettings.appLanguage` (persisted, default `.system`), wired via
`.environment(\.locale, appSettings?.appLanguage.locale ?? .autoupdatingCurrent)` at the app root
in `SudokuiOSApp.swift`. That single line is the **entire** mechanism for changing displayed
language live — see below for why nothing else works.

**Confirmed root cause of "language switch doesn't affect X" bugs (found via a concrete A/B
comparison: `LevelPreviewModal`'s `Text("Level \(level.id)")` translated correctly; the identical
text built via `MainMenuView`'s `localized("Level \(session.levelID)")` never did, no matter how
much reactivity plumbing was added):**
- `Text("literal, even with \(interpolation)")` resolves as a `LocalizedStringKey` against
  whatever `\.environment(\.locale)` currently is, **every single render**, completely
  independent of whether the enclosing view's `body` even re-executes. This is what makes it
  reliable — SwiftUI re-resolves environment-dependent content on its own.
- `String(localized: key, locale: someExplicitLocale)` — the mechanism the old `localized(_:)`
  helper (`LocalizationManager.swift`) used to bypass the device's locale — **does not reliably
  honor an explicit non-default `locale:` override in this project**. Its result is a plain
  `String`, frozen at the moment it's computed, with no path back to the environment at all.
  Two earlier rounds of fixes (making `LocalizationManager` `@Observable`, then manually wiring
  `@Environment(AppSettings.self)` + `.id(settings.appLanguage)` into a dozen views to force
  re-computation) never worked, because they only addressed *when* the string gets recomputed —
  the recomputed value itself was still wrong.
- **The fix, applied throughout: stop using `localized(_:)`/`String(localized:locale:)` for
  anything that gets displayed.** Enum `.text`/`.displayName`/`.shortName` properties
  (`SudokuRuleType`, `LevelSelectionViewModel.LevelFilter`, `LevelBuilderViewModel.GlobalRule`,
  `AppSettings`'s `MistakeMode`/`HintTarget`/`AppTheme`/`AppLanguage`) now return either a plain,
  untranslated **English catalog key** (`String`) or a `LocalizedStringKey` directly, and every
  display site wraps the raw key in `LocalizedStringKey(...)` before handing it to `Text(...)` —
  e.g. `Text(LocalizedStringKey(rule.shortName))`, not `Text(rule.shortName)`. This routes
  everything through the one mechanism confirmed to work. `LocalizationManager.shared` still
  exists and is still used by `localized(_:)` for the one remaining case that can't go through
  `Text` at all — see below.
- **Mixed-use strings** (compared, `.uppercased()`'d, or persisted *and* displayed) stay as plain
  `String` catalog keys (English) rather than pre-translated values — e.g.
  `SudokuGameViewModel.levelTitle`/`hintErrorMessage`, `SudokuRuleType.displayName`/`.shortName`.
  `SudokuGameViewModelTests` asserts `levelTitle == "Level 1"` directly, which is one more reason
  these must stay untranslated English, not a `localized(_:)` result — wrap only at the display
  site (`Text(LocalizedStringKey(...))`, or `.alert(LocalizedStringKey(...), isPresented:)` for a
  `String`-typed alert title).
- **User-generated content must NOT be wrapped in `LocalizedStringKey`** — a custom level's own
  title/name (`customLevel.levelName`, `gameViewModel.customLevelTitle`) is arbitrary text that
  happens to be harmless if wrapped (an unmatched catalog key just displays verbatim), but use
  `Text(verbatim:)` for it anyway to avoid an unlikely collision (a level named exactly "Custom
  Level", for instance) ever getting silently reinterpreted as a translation key.
- Building a `Text` from a mix of user content and a catalog-key fallback (e.g. "Level N or the
  custom title, followed by the rule name") uses `Text` concatenation (`Text(...) + Text(...)`)
  so each half resolves independently and correctly — see `SudokuGameView.swift`'s
  `SudokuPauseOverlayView.titleText` for a worked example.
- **A plain `String` needed outside SwiftUI** (where `LocalizedStringKey` doesn't apply at all)
  uses `localizedFormat(_:)` (`LocalizationManager.swift`) instead of `localized(_:)` —
  a `Bundle`-based lookup (finds the target language's `.lproj`, reads the format string via the
  classic `Bundle.localizedString(forKey:value:table:)` API, a different code path than the
  broken `String(localized:locale:)`) — pass its result to `String(format:)` with the
  interpolated arguments. Used for `LevelBuilderViewModel`'s default custom-level name
  (`"Level %lld"`, pre-filled into an editable text field before the user renames it). Falls back
  to the untranslated English key if the target bundle can't be found — a safe, no-worse-than-
  before fallback, not a crash.
- **One remaining known gap**: `SettingsView.swift`'s mail-support `subject`/`messageBody`
  (passed to `MFMailComposeViewController`) still use `localized(_:)` (the broken
  explicit-locale path), not yet migrated to `localizedFormat(_:)`. Low priority — only seen when
  composing a support email — but if picked up, follow the same pattern as
  `LevelBuilderViewModel` above.
- `NavigationStack`'s native nav-bar title has a **separate, unrelated** staleness quirk: even
  though it's a plain literal (`.navigationTitle("Settings")`, correctly environment-driven), the
  underlying UIKit title view doesn't reliably re-read it on a plain re-render. Fixed by pinning
  `.id(settings.appLanguage)` on the **entire outermost `NavigationStack`** (not an inner
  modifier like the `Form` — that left the title exactly one language-switch behind, always
  showing the *previous* selection). See `SettingsView.swift`.

**How it actually works — read this before touching any user-facing text:**
- A literal string passed directly to `Text("...")`, `Button("...") { }`, `Label("...", systemImage:)`,
  `.navigationTitle("...")`, `.alert("...", ...)`, `Picker("...", selection:)`, etc. auto-localizes
  with **zero source changes** — SwiftUI treats string literals as `LocalizedStringKey`, which
  does a catalog lookup. This covers the large majority of the app's UI text already.
- A custom view's own `String`-typed parameter that gets rendered via `Text(param)` internally
  does **not** auto-localize (Swift picks the verbatim, non-localizing overload for a runtime
  `String`). Fix: change the parameter's type to `LocalizedStringKey` (e.g. `EncyclopediaItem`,
  `EncyclopediaCard`, `VariantDocItem` in `HowToPlayView.swift`; `StaticRuleCardView`'s
  `title`/`description` in `RulesView.swift`; `BuilderToolButton` in `LevelBuilderView.swift`).
  This is a one-line fix per struct declaration, not per call site, as long as every call site
  already passes a literal — but first confirm the parameter isn't *also* used for something
  other than display (comparison, `ForEach(id:)`, hashing) — `LocalizedStringKey` doesn't reliably
  support those. `LevelIconsInfoView`'s `legends` array is a real example: its `ForEach` used to
  key on `\.title`, which had to move to `\.icon` before `title` could become a `LocalizedStringKey`.
- A `String` used in **mixed contexts** — both display *and* manipulation (`.uppercased()`,
  `.replacingOccurrences()`, string comparison, persistence) — stays typed as `String` and holds
  the **plain, untranslated English catalog key** (not a pre-resolved translation — see the
  confirmed root cause above for why). Wrap it in `LocalizedStringKey(...)` only at the display
  site. Real examples: `SudokuRuleType.displayName`/`.shortName` (used with `.uppercased()` /
  `.textCase(.uppercase)` elsewhere), `AppSettings`'s `MistakeMode`/`HintTarget`/`AppTheme`
  `.text` properties (these ended up pure-display, so they're typed `LocalizedStringKey` directly
  instead), `LevelFilter.text` / `LevelBuilderViewModel.GlobalRule.text`,
  `SudokuGameViewModel.hintErrorMessage` and `.levelTitle` (the latter two also asserted on
  directly by `SudokuGameViewModelTests`, another reason they can't hold pre-translated text).
- **Never use display text for control flow.** `LevelBuilderView.swift` used to check
  `message.message == "Level saved successfully!"` to decide whether to navigate back after a
  save — that breaks the instant the string is localized (the runtime value becomes French/
  Ukrainian text, no longer matching the English literal). Fixed by adding a dedicated
  `BuilderMessage.shouldNavigateBack: Bool` flag instead, decoupled entirely from the display
  text. If you find another string-equality-as-logic pattern, apply the same fix — don't just
  localize the string and hope the comparison still works.
- **Interpolated strings** (`Text("Level \(id)")`, `LocalizedStringKey("Level \(id)")`) auto-extract
  as format-string keys with printf-style specifiers matching the interpolated value's Swift type
  — `%lld` for `Int`, `%@` for `String`/`CustomStringConvertible`. The catalog's JSON **key** must
  be the format-specifier form (e.g. `"Level %lld"`), never the literal Swift interpolation syntax
  — the interpolation syntax isn't valid JSON and isn't what Xcode's extractor produces anyway.
  This is the single easiest mistake to make when hand-editing the catalog; if a translated screen
  falls back to raw English for a specific dynamic string, mismatched format specifiers on that
  key are the first thing to check. Prefer building the interpolated value as a literal
  `Text("...")`/`LocalizedStringKey("...")` directly at the display site over pre-computing a
  `String` and wrapping it later — it's the same result but avoids the "is this value already
  resolved or still a raw key" ambiguity that caused the root-cause bug above.
- A word embedded mid-sentence via interpolation (e.g. `"...for this \(isRow ? "row" : "column")."`)
  does **not** get independently localized — the substituted word is inserted verbatim in whatever
  language it was written in, and word order can't adapt per-language. Restructure into two full,
  separate `Text(...)`/`String(localized:)` literals instead (see the Sandwich-clue alert in
  `LevelBuilderView.swift` for a worked example) — don't interpolate a translatable word fragment
  into an otherwise-literal sentence.
- Brand/wordmark text (`SplashView.swift`'s "SUDOKU"/"VERSA"), user-generated content (custom
  level names, `customLevelTitle`), and the support email address are intentionally **not** in
  the catalog — they're either not translatable content or must stay verbatim.
- `RulesView.swift` (in-game "How to Play" sheet) and `HowToPlayView.swift` (the Encyclopedia)
  maintain independently-worded rule explanations for the same variants — both copies are in the
  catalog as separate keys since the English source text itself differs between the two files.

**Verification caveat**: the bulk of this catalog was built by hand (this environment has no
Xcode to run compiler-based extraction), enumerating every string via a full-codebase audit —
then cross-checked against a real Xcode build's automatic extraction, which is confirmed to
correctly merge into this same file (found as alphabetically-resorted, `"state": "new"` entries
with only an `"en"` value). That real pass caught a few things the manual audit missed:
`SettingsView.swift`'s `"Enable Mistake Limit (3 Strikes)"` Toggle label is different text from
the Encyclopedia's shorter `"Enable Mistake Limit"` item (both are now separate, correct keys);
`CustomGameWrapperView.swift`'s `"Loading level..."` indicator wasn't audited by any research
pass; and two `Text(...)` calls with multiple interpolations extract as a **single combined
key** with positional specifiers (`"%1$@ • %2$@"`, not two separate keys) — worth remembering
when hand-adding a key for a multi-interpolation `Text` call. If Xcode's own extraction runs
again (any build does this automatically) and adds more `"state": "new"` entries, that means a
real string this doc's manual audit missed — check `docs/reference/GAMEPLAY_CONTROLS.md`'s scope
notes for which files weren't covered by the original three research passes (`LevelViewModel.swift`
and `CustomGameWrapperView.swift` weren't), fill in `fr`/`uk` for the new key, and set its state
back to `"translated"`.
