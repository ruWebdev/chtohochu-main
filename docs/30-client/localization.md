# Flutter Localization

## 1. Purpose

This document defines how the ЧтоХочу Flutter client localizes user-facing strings. It implements the AGENTS.md rule "All user-facing strings MUST be localized" and prepares the app for additional languages without changing UI or business logic.

Current state: **Russian (`ru`) is the only available language.** The mechanism supports adding `en`, `de`, `fr`, `es`, `pt` etc. later by adding ARB files and enabling locales.

---

## 2. Mechanism

Standard Flutter `gen_l10n` + ARB files.

| Piece | Location |
|-------|----------|
| ARB catalogs | `apps/client/lib/l10n/app_ru.arb` |
| Config | `apps/client/l10n.yaml` |
| Generated code | `apps/client/lib/l10n/app_localizations*.dart` (generated — never edit) |
| Access + error mappers | `apps/client/lib/l10n/l10n.dart` |
| Wiring | `MaterialApp.router` in `lib/app/app.dart` |

`pubspec.yaml` has `flutter: generate: true` — generation runs as part of `flutter pub get` / build. To regenerate manually: `flutter gen-l10n` (or `dart run build_runner`-free; gen_l10n is built into the tool).

---

## 3. Usage in UI

```dart
import 'package:chtohochu/l10n/l10n.dart';

final l10n = context.l10n;           // extension on BuildContext
Text(l10n.wishSave)
SnackBar(content: Text(l10n.linkCopied))
```

or `AppLocalizations.of(context)` (non-nullable — configured via `nullable-getter: false`).

Rules:

- Use semantic keys: `wishSave`, `friendAddFailed`, `navWishes`. Never the Russian text itself as a key.
- Never build sentences by concatenation. Use placeholders:

```json
"wishDeleteMessage": "«{title}» будет удалено без возможности восстановления.",
"@wishDeleteMessage": {
  "placeholders": { "title": { "type": "String" } }
}
```

- Pluralization goes through ICU `plural` in ARB — not manual `if` on the number:

```json
"wishesCount": "{count, plural, one{{count} желание} few{{count} желания} many{{count} желаний} other{{count} желаний}}"
```

- Dates/numbers go through `intl` formatters (`shared/utils/formatters.dart`: `formatDate`, `formatPrice`). Date symbols for `ru` are initialized once in `main()` via `initializeDateFormatting('ru')` — bundled locally, no network.
- Add a `@key` `description` whenever the context isn't obvious from the key name.

---

## 4. What NOT to localize

- Technical identifiers and API/storage values: routes, enum codes, outbox entity types, storage keys, provider codes (`'vk'`, `'yandex'`).
- User content: names, wish titles, usernames — data, not UI strings.
- Backend validation text (HTTP 422 `errors.*`): the backend already returns localized text — presentation shows it as-is (`AuthValidationError.serverMessage`). Do not re-translate.
- Product name in `AppInfo.name` — technical constant (brand).

`lib/features/showcase/` is a dev-only exception: demo screens keep hardcoded strings on purpose.

---

## 5. Errors: typed codes → text

Domain/data layers throw typed errors carrying **technical codes**, not user text:

```dart
class WishNotAuthenticatedError extends WishError {
  const WishNotAuthenticatedError() : super('not_authenticated');
}
```

Presentation maps them to localized text via the helpers in `lib/l10n/l10n.dart`:

```dart
} on WishError catch (e) {
  showSnackBar(wishErrorMessage(context.l10n, e));
}
```

Available mappers: `authErrorMessage`, `wishErrorMessage`, `shoppingErrorMessage`, `friendsErrorMessage`, `profileErrorMessage`. When adding a new error subtype to a sealed class, extend the corresponding mapper — the compiler will flag an incomplete switch.

Controllers store the **error object** in state (e.g. `AuthFormIdle.error` is `AuthError?`), not a pre-rendered string — so text resolution happens in the widget with a live `AppLocalizations`.

---

## 6. Locales and fallback

`lib/app/app.dart`:

```dart
locale: const Locale('ru'),
supportedLocales: AppLocalizations.supportedLocales,
localizationsDelegates: AppLocalizations.localizationsDelegates,
```

- `supportedLocales` comes from the generated list — currently `[Locale('ru')]` only.
- `locale` is pinned to `ru`: the device system language cannot switch the app UI.
- If a device locale outside `supportedLocales` is requested anyway, Flutter resolves to the first supported locale — the app renders Russian; no runtime exception (covered by `test/l10n/localization_test.dart`).

`AppLocalizations.delegate.isSupported(locale)` is the source of truth for supported languages.

---

## 7. Fallback values in the data layer

Presentation fallbacks are NOT persisted. Example: an empty friend name is stored as `''` in Drift; the UI renders `l10n.noName` via `friendDisplayName(l10n, name)` in `friends_formatters.dart`. Never write `'Без имени'`-style fallbacks into Drift/outbox/API payloads — they would leak a locale into stored data.

---

## 8. Adding a new language (future)

1. Create `lib/l10n/app_en.arb` with `@@locale: en` and every key from `app_ru.arb` (placeholders must match).
2. Regenerate: `flutter gen-l10n` — `AppLocalizationsEn` and `supportedLocales` update automatically.
3. Decide availability: simply adding the ARB adds the locale to `supportedLocales`. Until a language switcher exists, `locale: const Locale('ru')` still pins the UI to Russian — enable the new locale explicitly when product decision is made.
4. For dates: `formatDate(date, l10n.localeName)`; add `initializeDateFormatting('<locale>')` in `main()` for the new language.

No UI or logic changes are needed — all strings already resolve through `context.l10n`.

---

## 9. Adding a new string

1. Add key + value + `@key` metadata (description, placeholders) to `app_ru.arb`.
2. Run `flutter gen-l10n` (or `flutter pub get` / build — `generate: true`).
3. Use `context.l10n.<key>` in the widget.

Do not add Russian literals to widget code — analyzer-visible keys are the only contract.
