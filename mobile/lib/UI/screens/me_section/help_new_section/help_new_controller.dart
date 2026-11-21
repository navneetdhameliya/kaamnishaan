import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/support_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../common_widgets/kn_dictation.dart';
import '../../../common_widgets/kn_toast.dart';

/// M47 New help request: what it is about, a short subject and the message.
class HelpNewController extends GetxController {
  HelpNewController({
    required this.repository,
    required this.dictation,
    Future<String?> Function()? appVersion,
  })
      : _appVersion = appVersion ?? _packageVersion;

  static Future<String?> _packageVersion() async {
    try {
      final p = await PackageInfo.fromPlatform();
      return '${p.version}+${p.buildNumber}';
    } catch (_) {
      return null;
    }
  }

  final ISupportApiRepository repository;

  /// Speak instead of typing (the microphone in the text box).
  final Dictation dictation;
  final Future<String?> Function() _appVersion;

  static const categories = ['problem', 'question', 'billing', 'feature'];

  final RxString category = 'problem'.obs;
  final subject = TextEditingController();
  final message = TextEditingController();
  final RxBool sending = false.obs;
  final RxnString error = RxnString();
  final RxInt _typed = 0.obs;

  @override
  void onInit() {
    super.onInit();
    void touch() => _typed.value++;
    subject.addListener(touch);
    message.addListener(touch);
  }

  @override
  void onClose() {
    dictation.cancel();
    subject.dispose();
    message.dispose();
    super.onClose();
  }

  String label(String c) => switch (c) {
        'question' => LangKeys.helpCatQuestion.tr,
        'billing' => LangKeys.helpCatBilling.tr,
        'feature' => LangKeys.helpCatFeature.tr,
        _ => LangKeys.helpCatProblem.tr,
      };

  String hint(String c) => switch (c) {
        'question' => LangKeys.helpCatQuestionHint.tr,
        'billing' => LangKeys.helpCatBillingHint.tr,
        'feature' => LangKeys.helpCatFeatureHint.tr,
        _ => LangKeys.helpCatProblemHint.tr,
      };

  bool get ready {
    _typed.value; // rebuild while typing
    return subject.text.trim().length >= 3 && message.text.trim().length >= 10;
  }

  void onDisabledTap() {
    error.value = subject.text.trim().length < 3 ? LangKeys.helpErrSubject.tr : LangKeys.helpErrMessage.tr;
  }

  Future<void> onSend() async {
    if (sending.value) return;
    if (!ready) {
      onDisabledTap();
      return;
    }
    error.value = null;
    sending.value = true;
    final result = await repository.create(
      TicketCreateModel(
        category: category.value,
        subject: subject.text.trim(),
        body: message.text.trim(),
        appVersion: await _appVersion(),
      ),
    );
    sending.value = false;
    final t = result.dataOrNull;
    if (t == null) {
      error.value = result.errorOrNull!.message;
      return;
    }
    KnToast.success(LangKeys.helpSent.tr);
    await Get.offNamed(RoutesConstants.helpTicketScreen, arguments: t.id);
  }
}
