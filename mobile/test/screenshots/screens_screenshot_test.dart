@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/common_widgets/kn_otp_boxes.dart';
import 'package:kaamnishaan/UI/screens/auth_section/join_company_section/join_company_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/join_company_section/join_company_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/otp_section/otp_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/otp_section/otp_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/phone_section/phone_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/phone_section/phone_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/profile_setup_section/profile_setup_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/profile_setup_section/profile_setup_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/intro_section/intro_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/intro_section/intro_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/language_section/language_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/language_section/language_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/splash_section/splash_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/splash_section/splash_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/welcome_section/welcome_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/welcome_section/welcome_screen.dart';
import 'package:kaamnishaan/UI/theme/kn_app_theme.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/config_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

class _StaticSplash extends SplashController {
  _StaticSplash({required super.session, required super.config, required super.prefs, required super.translation});

  @override
  Future<void> startApp() async => version.value = '0.1.0';
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Noto Sans', ['assets/fonts/NotoSans-Regular.ttf', 'assets/fonts/NotoSans-SemiBold.ttf', 'assets/fonts/NotoSans-Bold.ttf']);
  await load('Noto Sans Devanagari', ['assets/fonts/NotoSansDevanagari-Regular.ttf', 'assets/fonts/NotoSansDevanagari-SemiBold.ttf']);
  await load('Noto Sans Gujarati', ['assets/fonts/NotoSansGujarati-Regular.ttf', 'assets/fonts/NotoSansGujarati-SemiBold.ttf']);
  await load('Baloo 2', ['assets/fonts/Baloo2-Variable.ttf']);
  await load('DM Sans', ['assets/fonts/DMSans-Variable.ttf']);
  // the Lucide icon fonts (one per stroke weight) from the pub cache
  final cache = Directory('${Platform.environment['PUB_CACHE'] ?? '${Platform.environment['HOME']}/.pub-cache'}/hosted');
  final ttfs = cache
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.contains('lucide_icons_flutter') && f.path.endsWith('.ttf'))
      .toList();
  final icons = [
    LucideIcons.check,
    LucideIcons.check100,
    LucideIcons.check200,
    LucideIcons.check300,
    LucideIcons.check400,
    LucideIcons.check500,
    LucideIcons.check600,
  ];
  for (final icon in icons) {
    final family = icon.fontPackage == null ? icon.fontFamily! : 'packages/${icon.fontPackage}/${icon.fontFamily}';
    final digits = RegExp(r'\d+').firstMatch(icon.fontFamily!)?.group(0);
    final file = ttfs.firstWhere(
      (f) {
        final name = f.uri.pathSegments.last;
        final n = RegExp(r'\d+').firstMatch(name)?.group(0);
        return digits == null ? n == null : n == digits;
      },
      orElse: () => ttfs.first,
    );
    // ignore: avoid_print
    print('icon font ${icon.fontFamily} -> ${file.uri.pathSegments.last}');
    await load(family, [file.path]);
  }
}

void main() {
  late PreferencesService prefs;
  late MockAuthRepository repo;
  late SessionService session;
  late ConfigService config;

  setUpAll(() async {
    await initializeDateFormatting();
    await _loadFonts();
  });

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    repo = MockAuthRepository();
    session = SessionService(tokens: MemoryTokenStorage(), repository: repo);
    config = ConfigService(MockConfigRepository())
      ..config.value = const ConfigOutModel(
        languages: [],
        countries: [
          CountryOutModel(code: 'IN', name: 'India', dialCode: '+91', flag: '🇮🇳'),
          CountryOutModel(code: 'US', name: 'United States', dialCode: '+1', flag: '🇺🇸'),
        ],
        trades: [TradeOutModel(key: 'hvac', name: 'AC and cooling (HVAC)')],
        defaultCountry: 'IN',
        passwordMinLength: 8,
        minAppVersion: '0.1.0',
        maintenance: false,
        features: {},
      );
  });

  Future<void> shot(WidgetTester tester, String name, Widget screen, {Locale locale = const Locale('en', 'IN')}) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        translations: KnTranslations(),
        locale: locale,
        fallbackLocale: const Locale('en', 'IN'),
        theme: KnTheme.light(locale),
        home: screen,
      ),
    );
    for (final asset in ['assets/images/onboarding_photos.jpg', 'assets/images/welcome_invite.jpg']) {
      await tester.runAsync(() => precacheImage(AssetImage(asset), tester.element(find.byType(Scaffold).first)));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await expectLater(find.byType(GetMaterialApp), matchesGoldenFile('out/$name.png'));
    Get.deleteAll(force: true); // stops screen timers (the code countdown)
  }

  TranslationService translation() => TranslationService(prefs);

  testWidgets('M01 splash', (t) async {
    Get.put<SplashController>(_StaticSplash(session: session, config: config, prefs: prefs, translation: translation()));
    await shot(t, 'm01_splash', const SplashScreen());
  });

  testWidgets('M02 language', (t) async {
    Get.put(LanguageController(translation: translation(), prefs: prefs, speech: FakeSpeech()));
    await shot(t, 'm02_language', const LanguageScreen());
  });

  testWidgets('M03 intro', (t) async {
    Get.put(IntroController(prefs: prefs));
    await shot(t, 'm03_intro_1', const IntroScreen());
  });

  testWidgets('M04 welcome', (t) async {
    Get.put(WelcomeController());
    await shot(t, 'm04_welcome', const WelcomeScreen());
  });

  PhoneController phone(String digits, {bool error = false}) {
    final c = PhoneController(repository: repo, config: config, speech: FakeSpeech(), translation: translation());
    c.country.value = config.countries[1];
    for (final d in digits.split('')) {
      c.onDigit(d);
    }
    if (error) c.onDisabledSendTap();
    return Get.put(c);
  }

  testWidgets('M05 phone', (t) async {
    phone('5550102233');
    await shot(t, 'm05_phone', const PhoneScreen());
  });

  testWidgets('M05 phone invalid', (t) async {
    phone('55501022', error: true);
    await shot(t, 'm05_phone_invalid', const PhoneScreen());
  });

  OtpController otp(String code, KnOtpState state, String message) {
    final c = OtpController(
      repository: repo,
      session: session,
      prefs: prefs,
      speech: FakeSpeech(),
      translation: translation(),
      args: OtpArguments(
        phone: '+15550102233',
        display: '+1 (555) 010-2233',
        sent: OtpSentModel(challengeId: 'c', resendAfter: 24, expiresAt: DateTime(2026)),
      ),
    );
    c.code.value = code;
    c.state.value = state;
    c.errorMessage.value = message;
    c.secondsLeft.value = state == KnOtpState.normal ? 24 : 0;
    return Get.put(c);
  }

  testWidgets('M05 code', (t) async {
    otp('472', KnOtpState.normal, '');
    await shot(t, 'm05_code', const OtpScreen());
  });

  testWidgets('M05 code wrong', (t) async {
    otp('4729', KnOtpState.error, 'Wrong code. 2 tries left.');
    await shot(t, 'm05_code_wrong', const OtpScreen());
  });

  testWidgets('M05 code expired', (t) async {
    otp('472', KnOtpState.expired, 'This code expired. Get a new one.');
    await shot(t, 'm05_code_expired', const OtpScreen());
  });

  JoinCompanyController join(String status) {
    session.invites.assignAll([invite(status: status)]);
    final c = JoinCompanyController(
      repository: repo,
      session: session,
      config: config,
      speech: FakeSpeech(),
      translation: translation(),
    );
    return Get.put(c);
  }

  testWidgets('M10 join', (t) async {
    join('pending');
    await shot(t, 'm10_join', const JoinCompanyScreen());
  });

  testWidgets('M10 join expired', (t) async {
    join('pending').state.value = JoinState.expired;
    await shot(t, 'm10_join_expired', const JoinCompanyScreen());
  });

  testWidgets('M11 profile', (t) async {
    session.me.value = me();
    Get.put(
      ProfileSetupController(
        repository: repo,
        session: session,
        config: config,
        speech: FakeSpeech(),
        translation: translation(),
      ),
    );
    await shot(t, 'm11_profile', const ProfileSetupScreen());
  });

  testWidgets('icon stroke weights', (t) async {
    const rows = {
      'base': [LucideIcons.check, LucideIcons.volume2, LucideIcons.camera],
      '100': [LucideIcons.check100, LucideIcons.volume2100, LucideIcons.camera100],
      '200': [LucideIcons.check200, LucideIcons.volume2200, LucideIcons.camera200],
      '300': [LucideIcons.check300, LucideIcons.volume2300, LucideIcons.camera300],
      '400': [LucideIcons.check400, LucideIcons.volume2400, LucideIcons.camera400],
      '500': [LucideIcons.check500, LucideIcons.volume2500, LucideIcons.camera500],
      '600': [LucideIcons.check600, LucideIcons.volume2600, LucideIcons.camera600],
    };
    await shot(
      t,
      'icon_weights',
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in rows.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      SizedBox(width: 60, child: Text(e.key)),
                      for (final i in e.value) Padding(padding: const EdgeInsets.only(right: 24), child: Icon(i, size: 24)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('M02 language in Hindi', (t) async {
    Get.put(LanguageController(translation: translation(), prefs: prefs, speech: FakeSpeech()));
    await shot(t, 'm02_language_hi', const LanguageScreen(), locale: const Locale('hi', 'IN'));
  });
}
