# Sudoku Game

## Project Overview
iOS Sudoku game (SwiftUI + SwiftData) with 10 rule variants (Classic, Sandwich, Thermo, Arrow,
Killer, Kropki, Odd-Even, Knight's-move, King's-move, Non-Consecutive — combinable on one
level). 600 campaign levels plus a user-facing Level Builder for custom puzzles. Fully ad-free —
see "Ad SDK Removal" below for what was removed and the one remaining project-file cleanup step.
Localized into English, French, and Ukrainian — see "Localization" below before adding any new
user-facing string.

**Before scanning or grepping the codebase for a task, read `docs/reference/CODE_MAP.md`
first.** It's a routing index — "task X → file Y" — built specifically to avoid full-repo scans;
it also lists known dead code, shadowed duplicate files, and which test files currently don't
compile. Update it in the same commit whenever you add/move/delete/rename a file it references.

For the full mechanics of validation, the game loop, hints, solving, and level unlocking, treat
**`docs/reference/GAME_LOGIC_AND_RULES.md` as the source of truth** — it's derived directly
from the code and must be kept in sync with it. Don't re-derive that from scratch; read it
first, then update it in the same commit if you change behavior it describes.

For exactly what a specific button or control does, see **`docs/reference/GAMEPLAY_CONTROLS.md`**
(game screen, Level Builder, navigation, Settings) — same rule: read before re-deriving, update
in the same commit as any behavior change.

## Architecture
**Pattern**: MVVM
- **Models**: `SudokuLevel` (campaign level, Codable), `CustomSudokuLevel` (SwiftData `@Model`),
  `GameSession` (active-game persistence), `SudokuCellModel` (`@Observable` per-cell state)
- **ViewModels**: `LevelViewModel` (level collection, progress, unlocking), `SudokuGameViewModel`
  (core game engine — validation, move history, hints, timer; see the reference doc),
  `LevelBuilderViewModel` (custom level creation)
- **Views**: `MainMenuView` (`NavigationStack` root) → `SudokuGameView` (+ `SudokuBoardView`,
  `SudokuControlsView`, `SudokuHeaderView`) → overlays (Victory, pause, sandwich/killer helpers)
- **Services**: none ad/IAP-related remain — `EnvironmentConfig`, `NetworkMonitor`,
  `StoreManager`, and `HintSystemManager` were all deleted (dead and/or ad-related, see "Ad SDK
  Removal" below)
- **Known dead code**: `GameStateManager.swift`, `MoveHistoryManager.swift`, `TimerManager.swift`,
  `GamePersistenceManager.swift`, `OptimizedPotentialHighlightCalculator.swift` all still exist on
  disk but have **zero call sites** — abandoned parallel implementations, not wired into
  `SudokuGameViewModel`. Don't "fix" them expecting it to affect the app; either delete them or
  wire them in deliberately. Details in the reference doc §0.

## Swift Conventions
- Modern SwiftUI + Swift Concurrency; async/await used sparingly (main game loop is
  synchronous with manual timer management)
- Naming: camelCase properties/methods, PascalCase types
- State: `@Published`, `@State`, `@Observable` (Swift 5.9+), `@EnvironmentObject`,
  `@StateObject`/`@ObservedObject`/`@Environment`/`@Query`
- Access control: private by default, minimal public surface
- Comments: only for non-obvious logic (validation edge cases, hint/solver algorithms)

## Documentation Organization Policy 📁

**The project root holds only source files, project config, and `CLAUDE.md` itself.** Every
other Markdown file — reports, plans, checklists, summaries, diagrams — goes under `docs/`, in
the matching subfolder. Never create a `.md` file in the repo root or in `SudokuiOSTests/`.

```
docs/
├── ad-removal/   AdMob/GoogleMobileAds removal: plans, changes, cleanup notes
├── build-fixes/  Build error diagnosis and fix write-ups
├── optimization/ Performance/optimization reports
├── progress/     Phase/step logs, task summaries, "ready to commit" notes
├── reference/    Durable source-of-truth docs (GAME_LOGIC_AND_RULES.md, UNLOCK_SYSTEM_DIAGRAM.md)
│                 — update in place, don't fork a new dated file when behavior changes
└── testing/      Test plans, test-fix write-ups, testing checklists
```

Pick the subfolder that matches the doc's topic; if none fits, propose a new one under `docs/`
rather than defaulting to the root. Reference docs get updated in place; status/progress/plan
docs are historical logs and are fine to accumulate in their subfolder.

**Known gap**: Xcode's built-in Coding Intelligence assistant (the model picker in Xcode
Settings, as opposed to Claude Code) has no mechanism to read this file, so it won't follow this
policy and may drop a `.md` file at the root of either `SudokuiOS/` (this folder) or the outer
repo root (`/SudokuiOS/`, one level up, where `.git`/`SudokuiOS.xcodeproj` actually live — note
the two folders share a name, easy to mix up). This is expected, not a bug to chase — when a
Claude Code session notices a stray root-level `.md`, sweep it into the matching `docs/`
subfolder as routine cleanup (as happened with `HIGHLIGHT_TIMING_FIX.md` → `docs/build-fixes/`).

## Ad SDK Removal — Current Status

**Complete as of 2026-09-19** (verified against the live code, not just planning docs — re-verify
before trusting this if it's been a while, since another session has previously worked on this in
parallel; don't trust a `docs/ad-removal/*.md` status report over the actual code):

- `AdCoordinator.swift`, `BannerAdView.swift`, `InterstitialAdManager.swift`,
  `EnvironmentConfig.swift`, `NetworkMonitor.swift` — deleted. No `adCoordinator`/`AdCoordinator`
  references remain anywhere.
- `SudokuiOSApp.swift` — `GoogleMobileAds`/`AdSupport`/`AppTrackingTransparency` imports and the
  `MobileAds.shared.start(...)` + IDFA-logging init block removed.
- `Info.plist` — `GADApplicationIdentifier` and the ~55-entry `SKAdNetworkItems` array removed.
- The hint system (`SudokuGameViewModel.useHint()`) was already ad-free (flat 5-minute cooldown,
  no ad/IAP gating).
- **The "Remove Ads" IAP was removed entirely, not just its ad-related copy** — this was a
  deliberate product decision (explicitly confirmed), not just dead-code cleanup, because the
  purchase button had already been silently dropped from `SettingsView.swift` in an earlier pass
  while `StoreManager.swift` kept auto-restoring the flag for past purchasers, and that flag also
  unlocked all 600 levels (independent of ads) via `LevelViewModel`'s unlock algorithm. Deleted:
  `StoreManager.swift`, `HintSystemManager.swift` (dead + carried a rewarded-ad-shaped API),
  `AppSettings.didPurchaseRemoveAds`, `LevelViewModel.hasRemovedAds` and its "remove-ads unlocks
  everything" unlock rule (was Rule 3 in `recalculateLocks`). **Effect on existing customers**:
  anyone who previously purchased "Remove Ads" no longer gets automatic full-level access from
  that entitlement — levels now unlock only via normal sequential progression or the debug
  override. If this needs to be revisited (e.g. a real App Store Connect refund/support
  obligation), that's a product decision, not a code one — flag it back to the user, don't just
  restore the mechanic.
- Two Encyclopedia entries in `HowToPlayView.swift` ("Remove Ads", "Restore Purchases") removed
  to match — they described a purchase flow that no longer exists.
- `SequentialUnlockTests.swift` updated to drop the `hasRemovedAds` parameter and its "Remove Ads
  IAP unlocks all levels" test case. Three already-broken test files
  (`UnlockingLogicTests.swift`, `SudokuiOSTests/LevelSelectionTests.swift`,
  `SudokuiOSTests/LevelManagerTests.swift`) still reference the now-fully-removed
  `isAdUnlocked`/`unlockLevelViaAd` — not newly broken by this change, but now doubly stale; see
  `docs/reference/CODE_MAP.md` §4.
- Remove the `GoogleMobileAds` SPM dependency from the Xcode project itself (`project.pbxproj`
  package references) — this is the one piece that can't be done from a text-editing pass; needs
  Xcode or manual `.pbxproj` surgery.

## Localization

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

## Engineering Policies

**Build verification**: never claim a build succeeds without actually compiling it. If you can't
compile, say so explicitly ("I can't verify this builds — please run ⌘B") instead of "should
work." If you can compile, report the actual result (pass with zero errors, or the exact
remaining errors with file:line).

**Testing**: new logic (validation, calculations, game rules, state transitions, persistence)
needs a unit test; bug fixes need a regression test. Prefer Swift Testing (`@Test`/`#expect`)
for new tests; existing XCTest suites stay as-is. Don't test SwiftUI layout directly or trivial
getters/setters. Tests must be deterministic, isolated, and fast (<1s).

**Other standing rules**:
- Ask before changing core Sudoku validation/generation/hint algorithms in `SudokuGameViewModel`
  unless the task specifically requires it.
- Preserve SwiftData persistence (`@Model`/`@Query`) for custom levels and game sessions.
- Keep the `NavigationStack` + route-enum navigation structure intact.

## Quick Facts
- iOS 17+ (uses `@Observable`, SwiftData, modern SwiftUI)
- Persistence: SwiftData for levels/progress/custom levels, UserDefaults for simple flags and
  session-resume pointers
- 600 campaign levels (`Levels.json`): ids 1–250 single-variant cycling through all 10 rule
  types, ids 251–600 hybrid variants (always includes Non-Consecutive); sequential unlock with a
  full-section-1 gate before section 2 opens — see reference doc §3 for exact rules
- Custom levels: user-built via Level Builder, SwiftData-backed, no hard validation gate on save
  (only an advisory "human-solvable" check)
