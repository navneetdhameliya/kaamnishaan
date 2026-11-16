import 'dart:async';

import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/preferences_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../common_widgets/kn_otp_boxes.dart';
import '../../../common_widgets/kn_toast.dart';

/// What the phone screen passes to the code screen.
class OtpArguments {
  const OtpArguments({required this.phone, required this.display, required this.sent});

  final String phone;
  final String display;
  final OtpSentModel sent;
}

/// M05 SMS code: 4 digits, checked as soon as the 4th is typed.
class OtpController extends GetxController {
  OtpController({
    required this.repository,
    required this.session,
    required this.prefs,
    required this.speech,
    required this.translation,
    required this.args,
  });

  final IAuthApiRepository repository;
  final SessionService session;
  final PreferencesService prefs;
  final ISpeechService speech;
  final TranslationService translation;
  final OtpArguments args;

  static const codeLength = 4;

  late OtpSentModel sent = args.sent;
  late DateTime sentAt = DateTime.now();
  final RxString code = ''.obs;
  final Rx<KnOtpState> state = KnOtpState.normal.obs;
  final RxString errorMessage = ''.obs;
  final RxInt secondsLeft = 0.obs;
  final RxBool apiCallLoader = false.obs;
  Timer? _timer;

  String get resendText {
    final s = secondsLeft.value;
    return LangKeys.authResendIn.trParams({'time': '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}'});
  }

  String get sentAtText => DateFormat.jm(translation.currentCode).format(sentAt);

  @override
  void onInit() {
    super.onInit();
    _startTimer(sent.resendAfter);
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    secondsLeft.value = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft.value <= 1) {
        secondsLeft.value = 0;
        t.cancel();
      } else {
        secondsLeft.value--;
      }
    });
  }

  void onDigit(String digit) {
    if (state.value == KnOtpState.expired || apiCallLoader.value) return;
    if (state.value == KnOtpState.error) {
      code.value = '';
      state.value = KnOtpState.normal;
    }
    if (code.value.length >= codeLength) return;
    code.value += digit;
    if (code.value.length == codeLength) callVerifyOtpAPI();
  }

  void onBackspace() {
    if (state.value == KnOtpState.expired || code.value.isEmpty) return;
    if (state.value == KnOtpState.error) state.value = KnOtpState.normal;
    code.value = code.value.substring(0, code.value.length - 1);
  }

  void onHearErrorTap() => speech.speak(errorMessage.value, languageCode: translation.currentCode);

  void onChangeNumberTap() => Get.back<void>();

  Future<void> callVerifyOtpAPI() async {
    apiCallLoader.value = true;
    final result = await repository.verifyOtp(
      challengeId: sent.challengeId,
      code: code.value,
      deviceId: await prefs.deviceId(),
    );
    apiCallLoader.value = false;
    final newSession = result.dataOrNull;
    if (newSession != null) {
      _timer?.cancel();
      await session.apply(newSession);
      Get.offAllNamed(session.nextRoute());
      return;
    }
    final error = result.errorOrNull!;
    switch (error.code) {
      case 'otp_invalid':
        final left = error.details['attempts_left'];
        state.value = KnOtpState.error;
        errorMessage.value = LangKeys.authCodeWrong.trParams({'count': '${left ?? ''}'.trim()});
      case 'otp_expired':
        state.value = KnOtpState.expired;
        errorMessage.value = LangKeys.authCodeExpired.tr;
      case 'otp_too_many':
        state.value = KnOtpState.expired;
        errorMessage.value = LangKeys.authCodeTooMany.tr;
      default:
        code.value = '';
        KnToast.error(error.message);
    }
  }

  Future<void> callResendOtpAPI() async {
    if (apiCallLoader.value) return;
    apiCallLoader.value = true;
    final result = await repository.sendOtp(phone: args.phone);
    apiCallLoader.value = false;
    final newSent = result.dataOrNull;
    if (newSent == null) {
      final error = result.errorOrNull!;
      final wait = error.details['resend_after'];
      KnToast.error(wait != null ? LangKeys.authWaitResend.trParams({'seconds': '$wait'}) : error.message);
      return;
    }
    sent = newSent;
    sentAt = DateTime.now();
    code.value = '';
    state.value = KnOtpState.normal;
    errorMessage.value = '';
    _startTimer(newSent.resendAfter);
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
