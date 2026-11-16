import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:kaamnishaan/UI/screens/auth_section/phone_section/phone_binding.dart';
import 'package:kaamnishaan/UI/screens/auth_section/phone_section/phone_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/language_section/language_binding.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/language_section/language_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/language_section/language_screen.dart';
import 'package:kaamnishaan/UI/theme/kn_app_theme.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/services/config_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/speech_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Saves the language without GetX's full-app reload (that reload fights the test clock).
class _NoReloadTranslation extends TranslationService {
  _NoReloadTranslation(super.prefs);

  @override
  Future<void> change(String code) => prefs.setLanguageCode(code);
}

Future<void> _pumpApp(WidgetTester tester, GetPage<dynamic> page) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  await tester.pumpWidget(
    GetMaterialApp(
      translations: KnTranslations(),
      locale: const Locale('en', 'IN'),
      fallbackLocale: const Locale('en', 'IN'),
      theme: KnTheme.light(const Locale('en')),
      initialRoute: page.name,
      getPages: [page],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late FakeSpeech speech;

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    final prefs = await PreferencesService.create();
    speech = FakeSpeech();
    Get.put<PreferencesService>(prefs);
    Get.put<TranslationService>(_NoReloadTranslation(prefs));
    Get.put<ISpeechService>(speech);
    Get.put<ConfigService>(ConfigService(MockConfigRepository()));
    Get.put<IAuthApiRepository>(MockAuthRepository());
  });

  testWidgets('M05: the keypad types the number, and an incomplete number explains itself', (tester) async {
    await _pumpApp(tester, GetPage(name: '/phone', page: () => const PhoneScreen(), binding: PhoneBinding()));
    expect(find.text('Your phone number'), findsOneWidget);
    expect(find.text('Only used to log in. We never share it.'), findsOneWidget);

    for (final d in '98250'.split('')) {
      await tester.tap(find.byKey(ValueKey('key-$d')));
    }
    await tester.pump();
    expect(find.text('98250'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('send-code')));
    await tester.pump();
    expect(find.text('Enter a 10-digit phone number'), findsOneWidget);
    expect(find.text('Hear it'), findsOneWidget);

    await tester.tap(find.text('Hear it'));
    expect(speech.spoken.single, 'en:Enter a 10-digit phone number');
  });

  testWidgets('M02: tapping Hindi selects it and saves it', (tester) async {
    await _pumpApp(tester, GetPage(name: '/language', page: () => const LanguageScreen(), binding: LanguageBinding()));
    expect(find.text('Choose your language'), findsOneWidget);
    expect(find.text('English'), findsNWidgets(2)); // name and the English line under it
    for (final name in ['Español', 'हिन्दी', 'ગુજરાતી', 'Français']) {
      expect(find.text(name), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('lang-hi')));
    await tester.pump();
    expect(Get.find<LanguageController>().selectedCode.value, 'hi');
    expect(Get.find<PreferencesService>().languageCode, 'hi');
    await tester.tap(find.byKey(const ValueKey('lang-hi')).last); // speaker inside the card is separate
    await tester.tap(find.byIcon(LucideIcons.volume2).at(3)); // Hindi row speaker (after the hint icon)
    expect(speech.spoken.last, 'hi:हिन्दी');
  });
}
