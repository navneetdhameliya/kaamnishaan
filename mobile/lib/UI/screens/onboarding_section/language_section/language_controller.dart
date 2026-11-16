import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/services/preferences_service.dart';
import '../../../../infrastructure/services/speech_service.dart';

/// M02: pick the app language. The screen switches language as soon as one is tapped.
class LanguageController extends GetxController {
  LanguageController({required this.translation, required this.prefs, required this.speech});

  final TranslationService translation;
  final PreferencesService prefs;
  final ISpeechService speech;

  late final RxString selectedCode = translation.currentCode.obs;

  Future<void> onLanguageTap(String code) async {
    selectedCode.value = code;
    await translation.change(code);
  }

  void onSpeakerTap(AppLanguage language) => speech.speak(language.nativeName, languageCode: language.code);

  Future<void> onContinueTap() async {
    await translation.change(selectedCode.value);
    Get.offAllNamed(prefs.onboardingSeen ? RoutesConstants.welcomeScreen : RoutesConstants.introScreen);
  }
}
