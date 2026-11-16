import 'package:get/get.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';

/// Names and labels shared by the voice screens.
abstract final class VoiceTexts {
  static const _names = {
    'en': LangKeys.langEn,
    'hi': LangKeys.langHi,
    'gu': LangKeys.langGu,
    'es': LangKeys.langEs,
    'fr': LangKeys.langFr,
  };

  /// "Gujarati" for "gu" (in the app's language); the code itself for a language the app does not know.
  static String language(String? code) {
    if (code == null || code.isEmpty) return '';
    final base = code.split(RegExp('[-_]')).first.toLowerCase();
    final key = _names[base];
    return key == null ? code.toUpperCase() : key.tr;
  }

  /// The languages offered on the recorder, in their own script.
  static const chips = [('gu', 'ગુજરાતી'), ('hi', 'हिन्दी'), ('en', 'English')];
}
