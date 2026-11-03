# KaamNishaan mobile (Flutter + GetX)

One app for technicians and managers, phone + iPad + Mac.

## First-time setup (on your machine)
```bash
cd mobile
flutter create . --org com.kaamnishaan --project-name kaamnishaan --platforms=android,ios,macos
flutter pub get
flutter run --dart-define=KN_API_URL=http://10.0.2.2:8000
```
`flutter create .` only adds the platform folders (android/, ios/, macos/); it keeps `lib/`.

## Generated files — do not edit
- `lib/core/theme/kn_tokens.g.dart` ← `node shared/design-tokens/build.mjs`
- `lib/core/i18n/kn_translations.g.dart` ← `node shared/i18n/build.mjs`

Use `context.kn.<colour>` for semantic colours and `Theme.of(context).textTheme` for text — never hard-coded values.
