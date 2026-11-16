import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/UI/common_widgets/kn_otp_boxes.dart';
import 'package:kaamnishaan/UI/screens/auth_section/otp_section/otp_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/phone_section/phone_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/config_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthRepository repo;
  late PreferencesService prefs;
  late TranslationService translation;
  late FakeSpeech speech;

  setUp(() async {
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    translation = TranslationService(prefs);
    repo = MockAuthRepository();
    speech = FakeSpeech();
  });

  group('phone number', () {
    PhoneController phone() => PhoneController(
          repository: repo,
          config: ConfigService(MockConfigRepository()),
          speech: speech,
          translation: translation,
        );

    test('formats as typed and checks the length for the country', () {
      final c = phone();
      expect(c.country.value.dialCode, '+91');
      for (final d in '9825011111'.split('')) {
        c.onDigit(d);
      }
      expect(c.formatted, '98250 11111');
      expect(c.isValid, isTrue);
      expect(c.e164, '+919825011111');
      c.onDigit('1'); // no 11th digit for India
      expect(c.digits.value.length, 10);
      c.onBackspace();
      expect(c.isValid, isFalse);
    });

    test('US numbers look like (555) 010-2233', () {
      expect(PhoneController.formatNumber('+1', '5550102233'), '(555) 010-2233');
      expect(PhoneController.formatNumber('+1', '55501'), '(555) 01');
    });

    test('tapping the disabled button explains why, typing clears it', () {
      final c = phone();
      c.onDigit('9');
      c.onDisabledSendTap();
      expect(c.showError.value, isTrue);
      c.onHearErrorTap();
      expect(speech.spoken.single, startsWith('en:'));
      c.onDigit('8');
      expect(c.showError.value, isFalse);
    });

    test('a number the server rejects shows its message under the field', () async {
      when(() => repo.sendOtp(phone: any(named: 'phone'))).thenAnswer(
        (_) async => const ApiFailure<OtpSentModel>(
          ApiException(code: 'validation_error', message: 'Bad', fields: {'phone': 'This number is not valid'}),
        ),
      );
      final c = phone();
      for (final d in '1234567890'.split('')) {
        c.onDigit(d);
      }
      await c.callSendOtpAPI();
      verify(() => repo.sendOtp(phone: '+911234567890')).called(1);
      expect(c.showError.value, isTrue);
      expect(c.errorText, 'This number is not valid');
    });
  });

  group('SMS code', () {
    final sent = OtpSentModel(challengeId: 'ch1', resendAfter: 30, expiresAt: DateTime.now());

    OtpController otp() => OtpController(
          repository: repo,
          session: SessionService(tokens: MemoryTokenStorage(), repository: repo),
          prefs: prefs,
          speech: speech,
          translation: translation,
          args: OtpArguments(phone: '+919825011111', display: '+91 98250 11111', sent: sent),
        )..onInit();

    void typeCode(OtpController c, String code) {
      for (final d in code.split('')) {
        c.onDigit(d);
      }
    }

    void failWith(String code, [Map<String, dynamic> details = const {}]) {
      when(() => repo.verifyOtp(
            challengeId: any(named: 'challengeId'),
            code: any(named: 'code'),
            deviceId: any(named: 'deviceId'),
          )).thenAnswer((_) async => ApiFailure<SessionOutModel>(ApiException(code: code, message: code, details: details)));
    }

    test('the 4th digit checks the code; a wrong one shows tries left', () async {
      failWith('otp_invalid', {'attempts_left': 2});
      final c = otp();
      typeCode(c, '472');
      verifyNever(() => repo.verifyOtp(challengeId: any(named: 'challengeId'), code: any(named: 'code'), deviceId: any(named: 'deviceId')));
      typeCode(c, '9');
      await Future<void>.delayed(Duration.zero);
      expect(c.state.value, KnOtpState.error);
      // a new digit starts again
      c.onDigit('1');
      expect(c.state.value, KnOtpState.normal);
      expect(c.code.value, '1');
      c.onClose();
    });

    test('expired and too-many codes lock the keypad until a new code is sent', () async {
      failWith('otp_expired');
      final c = otp();
      typeCode(c, '4729');
      await Future<void>.delayed(Duration.zero);
      expect(c.state.value, KnOtpState.expired);
      c.onDigit('1');
      expect(c.code.value, '4729');

      when(() => repo.sendOtp(phone: any(named: 'phone'))).thenAnswer(
        (_) async => ApiSuccess<OtpSentModel>(OtpSentModel(challengeId: 'ch2', resendAfter: 45, expiresAt: DateTime.now())),
      );
      await c.callResendOtpAPI();
      expect(c.state.value, KnOtpState.normal);
      expect(c.code.value, '');
      expect(c.sent.challengeId, 'ch2');
      expect(c.secondsLeft.value, 45);
      c.onClose();
    });
  });
}
