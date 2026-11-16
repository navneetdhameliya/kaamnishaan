import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../../infrastructure/shared/navigation_utils.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M08 Forgot password. For privacy the backend answers the same whether or not the email has an
/// account, so the next screen always says "Check your email" (decision D-48).
class ForgotPasswordController extends GetxController {
  ForgotPasswordController({required this.repository, required this.speech, required this.translation});

  final IAuthApiRepository repository;
  final ISpeechService speech;
  final TranslationService translation;

  final TextEditingController emailController = TextEditingController();
  final RxString email = ''.obs;
  final RxBool showEmailError = false.obs;
  final RxBool apiCallLoader = false.obs;

  @override
  void onInit() {
    super.onInit();
    final prefill = Get.arguments;
    if (prefill is String && prefill.isNotEmpty) {
      emailController.text = prefill;
      email.value = prefill;
    }
  }

  bool get canSubmit => TextUtils.isValidEmail(email.value);

  void onEmailChanged(String value) {
    email.value = value;
    showEmailError.value = false;
  }

  void onDisabledSendTap() => showEmailError.value = true;

  void onHearErrorTap() => speech.speak(LangKeys.loginEmailInvalid.tr, languageCode: translation.currentCode);

  Future<void> callSendLinkAPI() async {
    if (!canSubmit) return onDisabledSendTap();
    apiCallLoader.value = true;
    final result = await repository.forgotPassword(email.value);
    apiCallLoader.value = false;
    if (result.isSuccess) {
      Get.toNamed(RoutesConstants.checkEmailScreen, arguments: email.value.trim());
      return;
    }
    final error = result.errorOrNull!;
    if (error.fields.containsKey('email')) {
      showEmailError.value = true;
    } else {
      KnToast.error(error.message);
    }
  }

  void onBackToLoginTap() => NavigationUtils.backToEmailLogin();

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}
