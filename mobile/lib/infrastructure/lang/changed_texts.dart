import 'package:get/get.dart';

import 'translations.g.dart';

/// Texts staff changed in the admin panel (A25 Localized content), put on top of the built-in ones.
///
/// The server sends {"hi": {"today.jobs": "आज के जॉब, {n}"}}; GetX keys its maps by locale ("hi_IN")
/// and writes placeholders as @n. A text changed back to the original is no longer sent, so the
/// built-in text is put back for any key that was changed before.
abstract final class ChangedTexts {
  static const _locales = {'en': 'en_IN', 'hi': 'hi_IN', 'gu': 'gu_IN', 'es': 'es_ES', 'fr': 'fr_FR'};
  static final Map<String, Set<String>> _applied = {};

  static String _getx(String text) => text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => '@${m[1]}');

  /// Turns the server's map into GetX's: locale -> key -> text. Unknown languages are skipped.
  static Map<String, Map<String, String>> toGetx(Map<String, dynamic> texts) {
    final out = <String, Map<String, String>>{};
    texts.forEach((lang, keys) {
      final locale = _locales[lang];
      if (locale == null || keys is! Map) return;
      out[locale] = {for (final e in keys.entries) '${e.key}': _getx('${e.value}')};
    });
    return out;
  }

  static void apply(Map<String, dynamic> texts) {
    final next = toGetx(texts);
    final restore = <String, Map<String, String>>{};
    Map<String, Map<String, String>>? builtIn;
    _applied.forEach((locale, keys) {
      final gone = keys.where((k) => !(next[locale]?.containsKey(k) ?? false));
      if (gone.isEmpty) return;
      builtIn ??= KnTranslations().keys;
      restore[locale] = {for (final k in gone) if (builtIn![locale]?[k] != null) k: builtIn![locale]![k]!};
    });
    if (restore.isNotEmpty) Get.appendTranslations(restore);
    if (next.isNotEmpty) Get.appendTranslations(next);
    _applied
      ..clear()
      ..addAll({for (final e in next.entries) e.key: e.value.keys.toSet()});
  }
}
