import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../services/preferences_service.dart';

/// One app language (M02). `english` is the second line under the native name.
class AppLanguage {
  const AppLanguage(this.code, this.locale, this.nativeName, this.english);

  final String code;
  final Locale locale;
  final String nativeName;
  final String english;
}

/// The 5 app languages, in the order of the M02 design, and switching between them.
class TranslationService {
  TranslationService(this.prefs);

  final PreferencesService prefs;

  static const languages = [
    AppLanguage('en', Locale('en', 'IN'), 'English', 'English'),
    AppLanguage('es', Locale('es', 'ES'), 'Español', 'Spanish'),
    AppLanguage('hi', Locale('hi', 'IN'), 'हिन्दी', 'Hindi'),
    AppLanguage('gu', Locale('gu', 'IN'), 'ગુજરાતી', 'Gujarati'),
    AppLanguage('fr', Locale('fr', 'FR'), 'Français', 'French'),
  ];
  static const fallbackLocale = Locale('en', 'IN');
  static List<Locale> get supportedLocales => languages.map((l) => l.locale).toList();

  static AppLanguage byCode(String? code) =>
      languages.firstWhere((l) => l.code == code, orElse: () => languages.first);

  /// The saved language, else the phone's language if we support it, else English.
  Locale get startLocale {
    final saved = prefs.languageCode;
    if (saved != null) return byCode(saved).locale;
    final phone = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return byCode(phone).locale;
  }

  bool get hasChosen => prefs.languageCode != null;

  String get currentCode => Get.locale?.languageCode ?? startLocale.languageCode;

  Future<void> change(String code) async {
    await prefs.setLanguageCode(code);
    await Get.updateLocale(byCode(code).locale);
  }
}
