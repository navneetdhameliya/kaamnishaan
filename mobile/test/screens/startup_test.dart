import 'dart:async';

import 'package:flutter/widgets.dart' show Locale, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/splash_section/splash_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/startup_error_section/startup_error_screen.dart';
import 'package:kaamnishaan/infrastructure/commons/constants/app_routes.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/services/config_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// A server that never answers (the free test server still waking up).
class _SlowSession extends SessionService {
  _SlowSession(MemoryTokenStorage tokens) : super(tokens: tokens, repository: MockAuthRepository());

  @override
  Future<String?> restore() => Completer<String?>().future;
}

/// Checking the saved login fails (for example the phone's key store can't be read).
class _BrokenSession extends SessionService {
  _BrokenSession() : super(tokens: MemoryTokenStorage(), repository: MockAuthRepository());

  @override
  Future<String?> restore() async => throw StateError('keystore');
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late PreferencesService prefs;

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
  });

  SplashController splash(SessionService session) => SplashController(
        session: session,
        config: ConfigService(MockConfigRepository()),
        prefs: prefs,
        translation: TranslationService(prefs),
        minimumTime: Duration.zero,
        restoreLimit: const Duration(milliseconds: 50),
      );

  group('M01 splash never waits forever', () {
    test('a saved login goes home when the server is slow', () async {
      final c = splash(_SlowSession(MemoryTokenStorage(access: 'a', refresh: 'r')));
      expect(await c.nextRoute(), RoutesConstants.homeScreen);
    });

    test('no saved login goes to the first-run screens when the server is slow', () async {
      final c = splash(_SlowSession(MemoryTokenStorage()));
      expect(await c.nextRoute(), isNull);
    });

    test('an error while checking the login does not stop the app', () async {
      expect(await splash(_BrokenSession()).nextRoute(), isNull);
    });
  });

  testWidgets('the "couldn\'t start" screen shows the words and Try again works', (t) async {
    var tries = 0;
    await t.pumpWidget(StartupErrorApp(error: StateError('boom'), onRetry: () => tries++));
    await t.pumpAndSettle();
    expect(find.text("KaamNishaan couldn't start"), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-error-detail')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('startup-retry')));
    expect(tries, 1);
  });
}
