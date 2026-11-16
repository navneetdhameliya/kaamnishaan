import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/config_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../common_widgets/kn_toast.dart';
import '../otp_section/otp_controller.dart';

/// M05 phone number: typed with the big keypad, sent as `+<country><number>`.
class PhoneController extends GetxController {
  PhoneController({required this.repository, required this.config, required this.speech, required this.translation});

  final IAuthApiRepository repository;
  final ConfigService config;
  final ISpeechService speech;
  final TranslationService translation;

  late final Rx<CountryOutModel> country = config.defaultCountry.obs;
  final RxString digits = ''.obs;
  final RxBool showError = false.obs;
  final RxnString serverError = RxnString();
  final RxBool apiCallLoader = false.obs;

  /// Digits after the country code. Others: 6–14.
  static const _lengths = {'+91': 10, '+1': 10, '+52': 10, '+34': 9, '+33': 9};

  int get requiredDigits => _lengths[country.value.dialCode] ?? 10;
  bool get hasFixedLength => _lengths.containsKey(country.value.dialCode);
  int get maxDigits => hasFixedLength ? requiredDigits : 14;

  bool get isValid =>
      hasFixedLength ? digits.value.length == requiredDigits : digits.value.length >= 6 && digits.value.length <= 14;

  String get e164 => '${country.value.dialCode}${digits.value}';

  String get errorText => serverError.value ?? LangKeys.authPhoneInvalid.trParams({'digits': '$requiredDigits'});

  /// (555) 010-2233 for +1, 98250 11111 for +91, groups of 3 otherwise.
  String get formatted => formatNumber(country.value.dialCode, digits.value);

  static String formatNumber(String dial, String d) {
    if (d.isEmpty) return '';
    if (dial == '+1') {
      if (d.length <= 3) return '($d';
      if (d.length <= 6) return '(${d.substring(0, 3)}) ${d.substring(3)}';
      return '(${d.substring(0, 3)}) ${d.substring(3, 6)}-${d.substring(6)}';
    }
    if (dial == '+91') return d.length <= 5 ? d : '${d.substring(0, 5)} ${d.substring(5)}';
    final parts = <String>[];
    for (var i = 0; i < d.length; i += 3) {
      parts.add(d.substring(i, i + 3 > d.length ? d.length : i + 3));
    }
    return parts.join(' ');
  }

  void onDigit(String digit) {
    if (digits.value.length >= maxDigits) return;
    digits.value += digit;
    _clearErrors();
  }

  void onBackspace() {
    if (digits.value.isEmpty) return;
    digits.value = digits.value.substring(0, digits.value.length - 1);
    _clearErrors();
  }

  void onCountrySelected(CountryOutModel c) {
    country.value = c;
    if (digits.value.length > maxDigits) digits.value = digits.value.substring(0, maxDigits);
    _clearErrors();
    Get.back<void>();
  }

  /// The button is disabled while the number is incomplete; tapping it says why (design rule).
  void onDisabledSendTap() => showError.value = true;

  void onHearErrorTap() => speech.speak(errorText, languageCode: translation.currentCode);

  Future<void> callSendOtpAPI() async {
    if (!isValid) return onDisabledSendTap();
    apiCallLoader.value = true;
    final result = await repository.sendOtp(phone: e164);
    apiCallLoader.value = false;
    final sent = result.dataOrNull;
    if (sent != null) {
      Get.toNamed(
        RoutesConstants.otpScreen,
        arguments: OtpArguments(phone: e164, display: '${country.value.dialCode} $formatted', sent: sent),
      );
      return;
    }
    final error = result.errorOrNull!;
    final fieldError = error.fields['phone'];
    if (fieldError != null || error.code == 'validation_error') {
      serverError.value = fieldError ?? error.message;
      showError.value = true;
    } else {
      KnToast.error(error.message);
    }
  }

  void _clearErrors() {
    showError.value = false;
    serverError.value = null;
  }
}
