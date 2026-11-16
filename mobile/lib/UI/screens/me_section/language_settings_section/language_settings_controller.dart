import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/me_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../common_widgets/kn_toast.dart';
import '../../voice_section/common/voice_texts.dart';

/// M38 Language: the app's language (on this phone and on the account), and the language customers
/// get reports in, which the company owner chooses (read only here).
class LanguageSettingsController extends GetxController {
  LanguageSettingsController({
    required this.me,
    required this.session,
    required this.translation,
  });

  final IMeApiRepository me;
  final SessionService session;
  final TranslationService translation;

  late final RxString selected = translation.currentCode.obs;
  final RxBool saving = false.obs;

  List<AppLanguage> get languages => TranslationService.languages;

  /// "English" — the company's report language, in the app's language.
  String get reportLanguage => VoiceTexts.language(session.me.value?.company?.reportLanguage ?? 'en');

  bool get changed => selected.value != translation.currentCode;

  void onLanguageTap(String code) => selected.value = code;

  /// Tells the account (a lost connection only skips that part), then switches the app.
  Future<void> onSaveTap() async {
    if (!changed) return Get.back<void>();
    saving.value = true;
    final result = await me.setLanguage(selected.value);
    if (result.dataOrNull != null) session.me.value = result.dataOrNull;
    await translation.change(selected.value);
    saving.value = false;
    KnToast.success(LangKeys.langSaved.tr);
    Get.back<bool>(result: true);
  }
}
