# KaamNishaan mobile — code standard

Based on the Neho app's structure (folders, screen/controller/binding, provider → repository →
controller, `.tr` localisation, custom widgets, constants), with the improvements agreed on
16 Nov 2026. Every mobile PR follows this file; a change to the standard is its own PR.

## 1. Folder structure
```
lib/
  main.dart                          start-up only: config, services, runApp
  UI/
    common_widgets/                  shared widgets, prefixed Kn… (kn_custom_button.dart …)
    commons/
      text_widgets/base/             CustomBaseTextWidget (all text goes through it)
      behaviour/                     scroll behaviour etc.
    theme/                           kn_app_theme.dart, kn_tokens.g.dart (from Figma tokens)
    screens/
      <feature>_section/             one folder per flow, e.g. onboarding_section/
        <screen>_section/            one folder per screen
          <screen>_screen.dart       UI only
          <screen>_controller.dart   state + methods
          <screen>_binding.dart      dependency wiring
          custom_widgets/            widgets used only by this screen
          mixins/                    to split a big controller (as Neho chat did)
  infrastructure/
    commons/constants/               app_routes.dart (RoutesConstants), app_pages.dart (AppPages),
                                     apis/api_constant.dart, image_constants.dart,
                                     storage_constants.dart, validator_constant.dart,
                                     method_constants.dart, app_constants.dart
    config/                          env.dart (build-time settings)
    data_access_layer/
      networks/                      api_client.dart, api_exception.dart, api_result.dart
      api_providers/                 <feature>_api_provider.dart   (one per feature)
      api_repository/                <feature>_api_repository.dart (one per feature)
      local_db/                      offline database (drift) — added with evidence capture
    lang/                            lang_keys.g.dart, translations.g.dart, translation_service.dart
    models/                          api_models.g.dart (generated) + hand-made view models
    services/                        session, token storage, connectivity, upload queue …
    shared/                          utils, extensions, logger
```
Names: files and folders `snake_case`; screen flows end in `_section`; classes `PascalCase`;
generated files end in `.g.dart` and are never edited by hand.

## 2. One screen = screen + controller + binding
- **Screen** `class XScreen extends GetView<XController>` — layout only. Rebuild with
  `GetBuilder<XController>` (or `Obx` for one small reactive part). No API calls, no business rules.
- **Controller** `class XController extends GetxController`
  - fields: `TextEditingController`, `FocusNode`, `GlobalKey<FormState>`, `RxBool` loaders,
    `Rx<Model>` data; dispose controllers and focus nodes in `onClose()`
  - methods: `callXxxAPI()` (talks to a repository), `onXxxTap()` (button handlers),
    `validateXxx()`; private helpers start with `_`
  - shows toasts and navigates; repositories never do
  - `static XController get to => Get.find();` when another screen needs it
- **Binding** `class XBinding extends Bindings` registers provider → repository → controller with
  `Get.lazyPut`; routes in `RoutesConstants`, pages in `AppPages` (`GetPage(name, page, binding)`).
- Navigation: `Get.toNamed(RoutesConstants.x, arguments: …)`; never push widgets directly.

## 3. API layers
```
XScreen → XController → IXApiRepository → IXApiProvider → ApiClient (dio) → backend
```
- **ApiClient** (one, shared): base URL from `Env`, adds `Authorization`, `Accept-Language`
  and `X-Device-Id`; on 401 refreshes the token once and retries; turns the backend error envelope
  `{error: {code, message, fields, details}}` into `ApiException`.
- **Provider** `abstract class IAuthApiProvider` + `AuthApiProvider implements …` — one method per
  endpoint, returns raw JSON. Paths come from `APIConstant`.
- **Repository** `abstract class IAuthApiRepository` + implementation — turns JSON into models and
  returns `ApiResult<T>` (success or `ApiException`). No `BuildContext`, no toasts, no navigation,
  so background sync and tests can use it.
- One provider and one repository **per feature** (auth, jobs, evidence, checklists, reports …);
  no file over ~600 lines.

## 4. Models
- Generated from the backend contract (`shared/api/openapi.generated.json`) by
  `mobile/tool/generate_models.py` into `infrastructure/models/api_models.g.dart`, in the Neho style:
  `class SessionOutModel` with `fromJson` / `toJson` and `sessionOutModelFromJson(String)` /
  `sessionOutModelToJson(...)`. Fields required by the contract are non-nullable; the rest nullable.
- CI fails if the models are older than the contract. Screen-only models (e.g. a form state) are
  hand-written next to the controller.

## 5. Localisation (5 languages)
- Texts live in `shared/i18n/{en,hi,gu,es,fr}.json` (one source for app, website and admin).
  `node shared/i18n/build.mjs` checks every language has every key and generates:
  - `lang_keys.g.dart` → `abstract final class LangKeys { static const authSendCode = 'auth.send_code'; … }`
  - `translations.g.dart` → the GetX maps
- In code: `LangKeys.authSendCode.tr`, with values `LangKeys.x.trParams({'name': n})`.
  Never a hard-coded user-facing string, never a raw `'auth.send_code'` string.
- The language picked on the first screen is saved and applied with `Get.updateLocale`.
- Server texts (errors, checklist questions) already arrive in the user's language
  (`Accept-Language`).

## 6. Theme, fonts, colours
- Colours and sizes come from the Figma tokens (`kn_tokens.g.dart`, generated by
  `shared/design-tokens/build.mjs`); read them with `context.kn.<name>` (meaning-based names such as
  `actionPrimary`, `textSecondary`, `statusDanger`). Light and dark both supported.
- Fonts: Noto Sans (+ Devanagari, Gujarati) chosen by language; weight via `fontWeight`,
  never one family per weight.
- Low-literacy rules from the PRD: tap targets ≥ 56 dp (`KnSize.tapTechnician`), icon + colour + word,
  labels ≤ 5 words, one action per screen, offline never blocks.

## 7. Common widgets (`UI/common_widgets/`)
`KnCustomButton` (primary / secondary / danger, loading), `KnCustomTextFormField`,
`CustomBaseTextWidget`, `CustomInkWell`, `KnPhoneField`, `KnOtpField`, `CommonLoader`,
`CommonShimmer`, `NoDataView`, `KnToast` (toastification), `KnAppBar`, spacing via
`SizedBox(height: KnSize.spaceX)`. Before writing a new widget, check this list; a widget used on
two screens moves here.

## 8. Constants and helpers
`APIConstant` (endpoint paths only — no keys, no base URL), `ImageConstants` (asset paths),
`StorageConstants` (storage keys), `ValidatorConstant` (form validators returning `LangKeys`
texts), `MethodConstants` (small static helpers), `AppConstants` (app-wide values).

## 9. Config and secrets
- No keys, tokens or server addresses in code or assets. Build-time values via
  `--dart-define` (see `Env`): `KN_API_URL`, `KN_FLAVOR` (local / staging / production).
- Login tokens in `flutter_secure_storage`; settings in `shared_preferences`.
- No `HttpOverrides` that skip certificate checks.

## 10. Offline first
Capture (photos, answers, voice notes) writes to the local database first, then an upload queue
sends it with `client_uuid` (safe to retry) when the internet is back (`workmanager`). The user is
never blocked by a missing connection.

## 11. Quality
- `flutter analyze` with no warnings; `dart format` (line length 110).
- No commented-out code, no `print`; log with `AppLogger` (silent in production).
- Tests: every controller (with `mocktail` fakes of the repository), every common widget, the
  API client (refresh, errors). CI runs analyze + test on every PR.
- Every screen has its states from Figma: loading, empty, error, offline, success, disabled.
- Any change to an approved screen goes to Figma first, then code.

## 12. Plugins (latest that work with Flutter 3.47.9, checked 16 Nov 2026)
| Purpose | Plugin |
|---|---|
| State, routing | get 4.7.3 |
| Network | dio 5.11.1 |
| Storage | flutter_secure_storage 11.2.0, shared_preferences 2.5.6, drift 2.35.4 + drift_flutter 0.3.1, path_provider 2.1.6 |
| Photos, voice | camera 0.12.2, image_picker 1.2.4, flutter_image_compress 2.5.1, record 7.2.0, just_audio 0.10.6, photo_view 0.15.0, signature 6.4.0, cached_network_image 4.0.7, flutter_svg 2.4.0 |
| Device | permission_handler 13.0.2, connectivity_plus 7.3.2, geolocator 14.0.1, device_info_plus 13.3.0, package_info_plus 10.2.2 |
| Background | workmanager 0.10.10 |
| Notifications | firebase_core 5.1.0, firebase_messaging 17.0.1, flutter_local_notifications 23.0.2 |
| UI | toastification 3.2.2, shimmer 4.0.0 |
| Utilities | intl 0.20.3, uuid 4.6.0, url_launcher 6.3.3, share_plus 13.3.1, app_links 7.2.2, crypto 3.0.8 |
| Dev | build_runner 2.17.1, drift_dev 2.35.3, mocktail 1.0.5, flutter_lints 6, flutter_native_splash 2.4.8, flutter_launcher_icons 0.14.4 |

A plugin is added in the step that first needs it (with its Android/iOS permissions), not before.
Upgrading Flutter or a plugin's major version is its own PR.
