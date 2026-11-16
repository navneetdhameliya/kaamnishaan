# KaamNishaan mobile (Flutter + GetX)

One app for technicians and managers: phone, iPad and Mac. Code follows **[STANDARDS.md](STANDARDS.md)**
(Neho structure: `lib/UI` + `lib/infrastructure`, screen + controller + binding, provider → repository).

## Run it (on your Mac)
```bash
cd mobile
flutter pub get
flutter run                                   # talks to the live test server (Render)
flutter run --dart-define=KN_API_URL=http://localhost:8000      # iOS simulator → your local backend
flutter run --dart-define=KN_API_URL=http://10.0.2.2:8000       # Android emulator → your local backend
```
Flutter **3.47.9** (same as CI). The first call to the free test server can take about a minute (it wakes up).

**Logging in on the test server:** enter a phone number, then read the 4-digit code at
`https://kaamnishaan-api.onrender.com/api/v1/dev/outbox?key=<KN_TEST_OUTBOX_KEY>` (see docs/deploy.md).
A technician needs an invite from an owner/manager first (`POST /api/v1/invites` in /docs).

## Checks
```bash
flutter analyze
flutter test
flutter test --tags screenshots --run-skipped --update-goldens   # PNGs of every screen in test/screenshots/out
```

## Generated files — never edit by hand
| File | Made by |
|---|---|
| `lib/UI/theme/kn_tokens.g.dart` | `node shared/design-tokens/build.mjs` (Figma tokens) |
| `lib/infrastructure/lang/lang_keys.g.dart`, `translations.g.dart` | `node shared/i18n/build.mjs` (texts in 5 languages) |
| `lib/infrastructure/models/api_models.g.dart` | `python3 mobile/tool/generate_models.py` (API contract) |

CI fails if any of them is out of date.
