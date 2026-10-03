# Flutter UI Architecture

## 1. Purpose

This document defines the UI architecture for the ЧтоХочу Flutter client. It covers Material 3, the centralized design system in `app/theme/`, typography (`AppTypography`), spacing (`AppSpacing`), colors (`ThemeColors`), component primitives in `shared/ui/`, localization requirements, and design-token rules.

This implements AGENTS.md §8 (Material 3 with centralized design system) and §15 (no hardcoded design tokens in feature widgets; no business rules in UI widgets).

---

## 2. Material 3

The app uses Material 3 (`useMaterial3: true`). The root is `MaterialApp.router` configured with the app theme and localizations.

```dart
MaterialApp.router(
  title: 'ЧтоХочу',
  theme: AppTheme.light(),
  darkTheme: AppTheme.dark(),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  routerConfig: goRouter,
)
```

Rules:

- Use Material 3 components as the base (`FilledButton`, `OutlinedButton`, `Card`, `NavigationBar`, `SearchBar`, etc.).
- Do not fight Material 3 with custom-painted equivalents when a Material widget suffices.
- Custom components are built on top of Material primitives, reusing the theme's colors/typography/shape.
- Dynamic color (Material You) is optional and must not be the only source of brand colors; the app defines explicit brand colors in `ThemeColors`.

---

## 3. Centralized Design System

All design tokens live in `app/theme/`. Feature widgets consume tokens from the theme; they do not define their own.

```text
app/theme/
├── app_theme.dart          # ThemeData construction (light + dark)
├── app_colors.dart         # ThemeColors (brand + semantic colors)
├── app_typography.dart     # AppTypography (named text styles)
├── app_spacing.dart        # AppSpacing (spacing scale)
├── app_radii.dart          # AppRadii (corner radii)
├── app_durations.dart      # animation durations
├── app_elevation.dart      # elevation tokens (if not using Material defaults)
└── app_icons.dart          # icon token mappings (optional)
```

### 3.1 Why centralize

- A single source of truth for visual language.
- Consistent light/dark handling.
- No magic numbers scattered across feature widgets (AGENTS.md §15: no hardcoded design tokens in feature widgets).
- Theming changes (e.g. a brand refresh) touch one directory, not every screen.

---

## 4. ThemeColors

`ThemeColors` defines brand and semantic colors. It is consumed via `Theme.of(context).extension<ThemeColors>()` so light and dark themes can supply different values.

```dart
@immutable
class ThemeColors extends ThemeExtension<ThemeColors> {
  const ThemeColors({
    required this.brand,
    required this.brandContainer,
    required this.onBrand,
    required this.success,
    required this.warning,
    required this.danger,
    required this.scrim,
  });

  final Color brand;
  final Color brandContainer;
  final Color onBrand;
  final Color success;
  final Color warning;
  final Color danger;
  final Color scrim;

  @override
  ThemeColors copyWith({...}) => ...;

  @override
  ThemeColors lerp(ThemeColors? other, double t) => ...;
}
```

Rules:

- Feature widgets read colors from `Theme.of(context)` (e.g. `theme.colorScheme.primary`, `theme.extension<ThemeColors>()!.brand`), never from hardcoded `Color(0xFF...)`.
- Semantic colors (`success`, `warning`, `danger`) are defined once and reused; do not invent per-feature reds/greens.
- Light and dark variants are both defined. A widget that only works in one mode is a bug.

---

## 5. AppTypography

Typography is semantic. Named styles are defined once; widgets reference them by name. Do not repeatedly construct arbitrary `TextStyle` values, and do not use chains of `copyWith()` as a substitute for a missing semantic style (AGENTS.md §15 / typography rules).

```dart
@immutable
class AppTypography {
  const AppTypography();

  TextStyle get displayLarge => ...;
  TextStyle get headlineMedium => ...;
  TextStyle get titleLarge => ...;
  TextStyle get bodyLarge => ...;
  TextStyle get bodyMedium => ...;
  TextStyle get labelLarge => ...;
  TextStyle get labelSmall => ...;
  TextStyle get caption => ...;

  // semantic, app-specific styles built on Material text themes
  TextStyle get listItemTitle => titleLarge.copyWith(fontWeight: FontWeight.w600);
  TextStyle get priceTag => titleMedium.copyWith(...);
  TextStyle get badge => labelSmall.copyWith(letterSpacing: 0.5);
}
```

Wired into `ThemeData.textTheme` so widgets can use `Theme.of(context).textTheme` and the app's semantic styles. App-specific semantic styles are exposed via a theme extension or a static accessor, not by ad-hoc `copyWith` in widgets.

Rules:

- Prefer `Theme.of(context).textTheme.xxx` for standard roles.
- For app-specific semantic roles (e.g. `listItemTitle`, `priceTag`), define them in `AppTypography` and expose through the theme.
- A widget must not inline `TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87)`. That is a hardcoded token.
- Color belongs to the theme, not the typography style — text colors come from `colorScheme.onSurface` etc., not baked into `AppTypography`.

---

## 6. AppSpacing

A spacing scale replaces magic padding/margin/gap values.

```dart
@immutable
class AppSpacing {
  const AppSpacing();

  static const double xxs = 4;
  static const double xs  = 8;
  static const double sm  = 12;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  // semantic gaps
  static const double contentPadding = md;
  static const double betweenFields  = md;
  static const double betweenCards   = sm;
  static const double sectionGap     = lg;
}
```

Rules:

- Use `AppSpacing.*` constants for `padding`, `margin`, `SizedBox`, `gap` in `Flex`/`Wrap`.
- Do not write `padding: EdgeInsets.all(16)` in a feature widget — use `AppSpacing.md`.
- Do not invent new spacing values per widget. If a new semantic gap is genuinely needed, add it to `AppSpacing` once.
- Component dimensions (button heights, input heights, avatar sizes) live in the design system too, either in `AppSpacing` or a dedicated `AppDimensions` file.

---

## 7. AppRadii and Other Tokens

```dart
class AppRadii {
  const AppRadii();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

class AppDurations {
  const AppDurations();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}
```

These are wired into `ThemeData` (`cardTheme`, `filledButtonTheme`, etc.) so Material components pick them up automatically, and are also available as constants for custom widgets.

---

## 8. Component Primitives (shared/ui/)

Reusable UI primitives live in `shared/ui/`. These are presentational widgets used across features. They contain no business logic and no feature-specific assumptions.

```text
shared/ui/
├── buttons/           # AppFilledButton, AppOutlinedButton, AppIconButton
├── cards/             # AppCard, AppListTile
├── inputs/            # AppTextField, AppSearchField
├── feedback/          # AppErrorView, AppEmptyState, AppLoadingIndicator
├── badges/            # AppBadge, AppChip
├── avatars/           # AppAvatar
├── sheets/            # AppBottomSheet
├── dialogs/           # AppAlertDialog
└── scaffolding/       # AppScaffold, AppAppBar
```

Rules:

- `shared/ui/` widgets consume only design tokens and the data passed into them.
- They do not call repositories, providers, or Riverpod (DI).
- They do not reference feature entities by type. If a list item needs feature data, the feature widget composes the primitive and passes primitives (strings, widgets) into it.
- Feature-specific widgets stay in `features/<feature>/presentation/widgets/`. Do not promote a feature-specific widget to `shared/ui/` prematurely.

### 8.1 Example primitive

```dart
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = AppSpacing.md});
  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      elevation: 0,
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    );
  }
}
```

---

## 9. Localization

All user-facing strings MUST be localized (AGENTS.md §8). Do not hardcode user-facing strings in widgets.

### 9.1 Setup

- Use Flutter's `gen-l10n` (ARB-based) with `AppLocalizations`.
- Supported locales are declared in `MaterialApp.supportedLocales`.
- Strings live in `lib/l10n/app_<locale>.arb`.

### 9.2 Usage

```dart
final l = AppLocalizations.of(context)!;
Text(l.shoppingListEmptyStateTitle)
```

Rules:

- No user-facing string literals in widget files. The only exception is developer/debug-only text that is never shown to end users.
- Placeholders use ICU message syntax (`{name}`, plurals).
- Do not concatenate localized fragments to form sentences — different locales reorder words. Use a single message with placeholders.
- Locale selection: user preference (SharedPreferences) → device locale → fallback (ru).
- Notification text is localized server-side (see `docs/20-backend/notifications.md`); the client renders the provided text for FCM banners and uses `AppLocalizations` for in-app UI.

### 9.3 Non-translatable content

Brand name "ЧтоХочу", proper nouns, and numeric/format values are not localized through ARB. Keep them as constants.

---

## 10. Design Token Rules

1. **No hardcoded tokens in feature widgets.** No `Color(0xFF...)`, no literal `fontSize`, no literal `BorderRadius.circular(8)`, no literal `EdgeInsets.all(16)`. Use the design system.
2. **One source of truth.** Colors in `AppColors`/`ThemeColors`, typography in `AppTypography`, spacing in `AppSpacing`, radii in `AppRadii`.
3. **Theme extensions for app-specific tokens.** Material's `ColorScheme`/`TextTheme` cover standard roles; app-specific roles go in `ThemeExtension`s.
4. **Light and dark parity.** Every token that varies by mode has both variants. A widget must render correctly in both.
5. **Semantic naming.** Prefer `AppSpacing.sectionGap` over `AppSpacing.lg` where a semantic name is stable. Semantic names survive rescaling.
6. **No magic strings.** Use constants/enums for keys, route names, icon identifiers (AGENTS.md §15).
7. **No business rules in UI widgets.** Widgets compose visuals and dispatch events; they do not compute business outcomes (AGENTS.md §15, §16).

---

## 11. Theme Construction

`AppTheme` builds `ThemeData` for light and dark, wiring tokens into Material component themes so all Material widgets inherit the design system.

```dart
class AppTheme {
  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark()  => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTypography.forBrightness(brightness),
      cardTheme: CardThemeData(shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      )),
      filledButtonTheme: FilledButtonThemeData(style: ...),
      extensions: [
        brightness == Brightness.light ? ThemeColors.light : ThemeColors.dark,
      ],
    );
  }
}
```

---

## 12. Accessibility

- Respect text scaling (do not hardcode fixed heights that clip scaled text).
- Maintain contrast ratios for text on backgrounds (use theme colors, which are tuned for contrast).
- Provide semantic labels for icon-only buttons (`Semantics(label: ...)` or `Tooltip`).
- Touch targets meet platform minimums (≥44pt iOS, ≥48dp Android).

---

## 13. Testing

- Widget tests for component primitives (render with sample props, light + dark).
- Snapshot/golden tests for key primitives where visual regression matters.
- Screen widget tests use stubbed providers and assert UI states (loaded, empty, error, offline).
- Localization smoke test: every supported locale renders key screens without missing-string exceptions.

See `docs/10-development/testing.md`.

---

## 14. Anti-Patterns

- Hardcoded `Color`, `TextStyle`, `EdgeInsets`, `BorderRadius` in feature widgets.
- `copyWith` chains in widgets to fake a missing semantic style.
- Feature widgets calling repositories directly (bypassing providers).
- Business logic inside `build()` (filtering, sorting, deriving state — that belongs in the provider/repository).
- Promoting a feature widget to `shared/ui/` because "it's reused in two places" without extracting a true primitive.
- English/Russian string literals in widget code.
- A custom-painted widget that duplicates a Material 3 component.
