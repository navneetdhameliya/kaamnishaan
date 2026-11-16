import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M06 Email login for managers and owners: wrong password shows tries left; after 5 wrong tries
/// the backend locks the email for 15 minutes and the form is closed until then.
class EmailLoginController extends GetxController {
  EmailLoginController({
    required this.repository,
    required this.session,
    required this.speech,
    required this.translation,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final IAuthApiRepository repository;
  final SessionService session;
  final ISpeechService speech;
  final TranslationService translation;
  final DateTime Function() _clock;

  /// The backend's rule: 5 wrong tries, then 15 minutes.
  static const maxTries = 5;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final RxString email = ''.obs;
  final RxString password = ''.obs;
  final RxBool showEmailError = false.obs;
  final RxBool showPasswordMissing = false.obs;
  final RxnInt attemptsLeft = RxnInt();
  final Rxn<DateTime> lockedUntil = Rxn<DateTime>();
  final RxBool apiCallLoader = false.obs;
  Timer? _unlockTimer;

  @override
  void onInit() {
    super.onInit();
    final prefill = Get.arguments;
    if (prefill is String && prefill.isNotEmpty) {
      emailController.text = prefill;
      email.value = prefill;
    }
  }

  bool get isLocked => lockedUntil.value != null;

  bool get canSubmit => !isLocked && TextUtils.isValidEmail(email.value) && password.value.isNotEmpty;

  String? get emailError => showEmailError.value ? LangKeys.loginEmailInvalid.tr : null;

  String? get passwordError {
    if (attemptsLeft.value != null) return LangKeys.loginWrong.trParams({'count': '${attemptsLeft.value}'});
    if (showPasswordMissing.value) return LangKeys.loginPasswordMissing.tr;
    return null;
  }

  int get lockedMinutes {
    final until = lockedUntil.value;
    if (until == null) return 0;
    final seconds = until.difference(_clock()).inSeconds;
    return seconds <= 0 ? 1 : (seconds / 60).ceil();
  }

  String get lockedTime {
    final until = lockedUntil.value;
    return until == null ? '' : DateFormat.jm(translation.currentCode).format(until);
  }

  void onEmailChanged(String value) {
    email.value = value;
    showEmailError.value = false;
    attemptsLeft.value = null;
  }

  void onPasswordChanged(String value) {
    password.value = value;
    showPasswordMissing.value = false;
    attemptsLeft.value = null;
  }

  /// Checked when the person leaves the email field, so the error does not shout while typing.
  void onEmailDone([String? _]) {
    if (email.value.trim().isNotEmpty && !TextUtils.isValidEmail(email.value)) showEmailError.value = true;
  }

  /// The button is disabled until the form is complete; tapping it says what is missing.
  void onDisabledLoginTap() {
    if (isLocked) return;
    if (!TextUtils.isValidEmail(email.value)) {
      showEmailError.value = true;
    } else if (password.value.isEmpty) {
      showPasswordMissing.value = true;
    }
  }

  void onHearEmailErrorTap() => _speak(emailError);

  void onHearPasswordErrorTap() => _speak(passwordError);

  void _speak(String? text) {
    if (text != null) speech.speak(text, languageCode: translation.currentCode);
  }

  Future<void> callLoginAPI() async {
    if (!canSubmit) return onDisabledLoginTap();
    apiCallLoader.value = true;
    final result = await repository.loginWithEmail(email: email.value, password: password.value);
    final data = result.dataOrNull;
    if (data != null) {
      await session.apply(data);
      apiCallLoader.value = false;
      Get.offAllNamed(session.nextRoute());
      return;
    }
    apiCallLoader.value = false;
    final error = result.errorOrNull!;
    switch (error.code) {
      case 'login_invalid':
        final left = error.details['attempts_left'];
        attemptsLeft.value = left is num ? left.toInt() : null;
        if (attemptsLeft.value == null) KnToast.error(error.message);
      case 'account_locked':
        final until = DateTime.tryParse('${error.details['locked_until']}');
        lock(until?.toLocal() ?? _clock().add(const Duration(minutes: 15)));
      case 'validation_error' when error.fields.containsKey('email'):
        showEmailError.value = true;
      default:
        KnToast.error(error.message);
    }
  }

  /// Closes the form until [until], then opens it again by itself.
  void lock(DateTime until) {
    attemptsLeft.value = null;
    lockedUntil.value = until;
    _unlockTimer?.cancel();
    final wait = until.difference(_clock());
    _unlockTimer = Timer(wait.isNegative ? Duration.zero : wait, () => lockedUntil.value = null);
  }

  void onForgotTap() =>
      Get.toNamed(RoutesConstants.forgotPasswordScreen, arguments: TextUtils.isValidEmail(email.value) ? email.value.trim() : null);

  void onPhoneLoginTap() => Get.toNamed(RoutesConstants.phoneScreen);

  void onCreateAccountTap() => Get.toNamed(RoutesConstants.ownerSignupScreen);

  @override
  void onClose() {
    _unlockTimer?.cancel();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
