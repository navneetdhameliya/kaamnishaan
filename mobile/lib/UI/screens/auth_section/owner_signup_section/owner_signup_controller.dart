import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// One password rule shown under the field ("Missing: 8 or more characters", "Done: A number").
class PasswordRule {
  const PasswordRule(this.label, this.met);

  final String label;
  final bool met;
}

/// M07 step 1: the owner's name, work email and password. Creates the account (POST /auth/register),
/// then step 2 sets up the company.
class OwnerSignupController extends GetxController {
  OwnerSignupController({
    required this.repository,
    required this.session,
    required this.speech,
    required this.translation,
  });

  final IAuthApiRepository repository;
  final SessionService session;
  final ISpeechService speech;
  final TranslationService translation;

  /// The backend's rule (GET /config password_min_length).
  static const minLength = 8;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode nameFocusNode = FocusNode();
  final RxString name = ''.obs;
  final RxString email = ''.obs;
  final RxString password = ''.obs;
  final RxBool agreed = false.obs;
  final RxBool showNameError = false.obs;
  final RxBool showEmailError = false.obs;
  final RxBool emailTaken = false.obs;
  final RxBool showPasswordRules = false.obs;
  final RxBool showTermsError = false.obs;
  final RxBool apiCallLoader = false.obs;

  /// Set once the account exists, so going back and forward does not try to create it again.
  String? registeredEmail;

  bool get hasLength => password.value.length >= minLength;
  bool get hasNumber => password.value.contains(RegExp(r'\d'));
  bool get hasLetter => password.value.contains(RegExp('[A-Za-z]'));
  bool get passwordStrong => hasLength && hasNumber && hasLetter;

  /// The rules in the order the design shows them; "A letter" only appears when it is missing.
  List<PasswordRule> get rules => [
        PasswordRule(LangKeys.signupRuleLength.tr, hasLength),
        PasswordRule(LangKeys.signupRuleNumber.tr, hasNumber),
        if (!hasLetter) PasswordRule(LangKeys.signupRuleLetter.tr, false),
      ];

  int get strength => [hasLength, hasNumber, hasLetter].where((r) => r).length;

  bool get canSubmit =>
      name.value.trim().isNotEmpty &&
      TextUtils.isValidEmail(email.value) &&
      !emailTaken.value &&
      passwordStrong &&
      agreed.value;

  String get initials => TextUtils.initials(name.value);

  String? get nameError => showNameError.value ? LangKeys.signupNameMissing.tr : null;

  String? get emailError {
    if (emailTaken.value) return LangKeys.signupEmailTaken.tr;
    if (showEmailError.value) return LangKeys.loginEmailInvalid.tr;
    return null;
  }

  bool get passwordHasError => showPasswordRules.value && !passwordStrong;

  void onNameChanged(String value) {
    name.value = value;
    if (value.trim().isNotEmpty) showNameError.value = false;
  }

  void onEmailChanged(String value) {
    email.value = value;
    showEmailError.value = false;
    emailTaken.value = false;
  }

  void onEmailDone([String? _]) {
    if (email.value.trim().isNotEmpty && !TextUtils.isValidEmail(email.value)) showEmailError.value = true;
  }

  void onPasswordChanged(String value) => password.value = value;

  /// Rules show once the person leaves the field (or taps Next) with a weak password.
  void onPasswordDone([String? _]) {
    if (password.value.isNotEmpty && !passwordStrong) showPasswordRules.value = true;
  }

  void onAgreeChanged(bool value) {
    agreed.value = value;
    if (value) showTermsError.value = false;
  }

  /// No separate voice button needed: focusing the field shows the keyboard, whose mic types speech.
  void onMicTap() => nameFocusNode.requestFocus();

  void onDisabledNextTap() {
    showNameError.value = name.value.trim().isEmpty;
    showEmailError.value = !TextUtils.isValidEmail(email.value);
    showPasswordRules.value = !passwordStrong;
    showTermsError.value = !agreed.value;
  }

  void onHearNameErrorTap() => _speak(nameError);

  void onHearEmailErrorTap() => _speak(emailError);

  void _speak(String? text) {
    if (text != null) speech.speak(text, languageCode: translation.currentCode);
  }

  void onLogInInsteadTap() => Get.offNamed(RoutesConstants.emailLoginScreen, arguments: email.value.trim());

  Future<void> callRegisterAPI() async {
    if (!canSubmit) return onDisabledNextTap();
    final cleanEmail = email.value.trim().toLowerCase();
    apiCallLoader.value = true;
    if (registeredEmail == cleanEmail) {
      // came back from step 2: the account exists, only the name may have changed
      final result = await repository.updateProfile(name: name.value.trim());
      apiCallLoader.value = false;
      final me = result.dataOrNull;
      if (me == null) return KnToast.error(result.errorOrNull!.message);
      session.me.value = me;
      Get.toNamed(RoutesConstants.companySetupScreen);
      return;
    }
    final result = await repository.registerOwner(name: name.value, email: email.value, password: password.value);
    apiCallLoader.value = false;
    final data = result.dataOrNull;
    if (data != null) {
      await session.apply(data);
      registeredEmail = cleanEmail;
      // M09: confirm the email first (it can be done later)
      Get.toNamed(
        session.me.value?.emailVerified ?? false ? RoutesConstants.companySetupScreen : RoutesConstants.verifyEmailScreen,
      );
      return;
    }
    final error = result.errorOrNull!;
    switch (error.code) {
      case 'email_taken':
        emailTaken.value = true;
      case 'password_weak':
        showPasswordRules.value = true;
      case 'validation_error' when error.fields.containsKey('email'):
        showEmailError.value = true;
      default:
        KnToast.error(error.message);
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    nameFocusNode.dispose();
    super.onClose();
  }
}
