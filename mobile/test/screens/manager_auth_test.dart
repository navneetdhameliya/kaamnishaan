import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/auth_section/check_email_section/check_email_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/company_setup_section/company_setup_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/email_login_section/email_login_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/forgot_password_section/forgot_password_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/owner_signup_section/owner_signup_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/profile_setup_section/profile_setup_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/config_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

ConfigService _config({List<TradeOutModel>? trades}) => ConfigService(MockConfigRepository())
  ..config.value = ConfigOutModel(
    languages: const [],
    countries: const [
      CountryOutModel(code: 'IN', name: 'India', dialCode: '+91', flag: '🇮🇳'),
      CountryOutModel(code: 'US', name: 'United States', dialCode: '+1', flag: '🇺🇸'),
    ],
    trades: trades ?? const [TradeOutModel(key: 'hvac', name: 'HVAC')],
    defaultCountry: 'IN',
    passwordMinLength: 8,
    minAppVersion: '0.1.0',
    maintenance: false,
    features: const {},
  );

const _company = CompanyOutModel(
  id: 'c1',
  name: 'BrightAir Services',
  trade: 'hvac',
  country: 'IN',
  timezone: 'Asia/Kolkata',
  currency: 'INR',
  reportLanguage: 'en',
  plan: 'professional',
  status: 'trial',
  settings: CompanySettingsModel(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthRepository repo;
  late TranslationService translation;
  late FakeSpeech speech;
  late SessionService session;

  setUpAll(() async {
    await initializeDateFormatting();
    registerFallbackValue(UploadKind.photo);
    registerFallbackValue(<int>[]);
  });

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    repo = MockAuthRepository();
    speech = FakeSpeech();
    session = SessionService(tokens: MemoryTokenStorage(), repository: repo);
  });

  void loginFails(String code, {Map<String, dynamic> details = const {}}) {
    when(() => repo.loginWithEmail(email: any(named: 'email'), password: any(named: 'password'))).thenAnswer(
      (_) async => ApiFailure<SessionOutModel>(ApiException(code: code, message: code, details: details)),
    );
  }

  group('M06 email login', () {
    EmailLoginController login({DateTime Function()? clock}) => EmailLoginController(
          repository: repo,
          session: session,
          speech: speech,
          translation: translation,
          clock: clock,
        );

    test('a bad email keeps the button off and says how an email looks', () {
      final c = login();
      c.onEmailChanged('priya@brightair');
      c.onPasswordChanged('secret123');
      expect(c.canSubmit, isFalse);
      c.onDisabledLoginTap();
      expect(c.emailError, 'Enter a valid email, like name@company.com');
      c.onHearEmailErrorTap();
      expect(speech.spoken.single, 'en:Enter a valid email, like name@company.com');
      c.onEmailChanged('priya@brightair.example');
      expect(c.emailError, isNull);
      expect(c.canSubmit, isTrue);
    });

    test('a wrong password shows the tries left; typing clears it', () async {
      loginFails('login_invalid', details: {'attempts_left': 3});
      final c = login()
        ..onEmailChanged('priya@brightair.example')
        ..onPasswordChanged('wrong-pass1');
      await c.callLoginAPI();
      verify(() => repo.loginWithEmail(email: 'priya@brightair.example', password: 'wrong-pass1')).called(1);
      expect(c.passwordError, 'Email or password is wrong. 3 tries left.');
      c.onPasswordChanged('wrong-pass2');
      expect(c.passwordError, isNull);
    });

    test('five wrong tries lock the form until the time the server gives', () async {
      loginFails('account_locked', details: {'locked_until': '2026-11-16T10:42:00'});
      final c = login(clock: () => DateTime(2026, 11, 16, 10, 27))
        ..onEmailChanged('priya@brightair.example')
        ..onPasswordChanged('wrong-pass1');
      await c.callLoginAPI();
      expect(c.isLocked, isTrue);
      expect(c.canSubmit, isFalse);
      expect(c.lockedMinutes, 15);
      expect(c.lockedTime, contains('10:42'));
      c.onDisabledLoginTap(); // no errors while locked
      expect(c.showEmailError.value, isFalse);
      c.onClose();
    });

    test('a good login saves the session', () async {
      when(() => repo.loginWithEmail(email: any(named: 'email'), password: any(named: 'password')))
          .thenAnswer((_) async => ApiSuccess<SessionOutModel>(session_()));
      final c = login()
        ..onEmailChanged('priya@brightair.example')
        ..onPasswordChanged('secret123');
      await c.callLoginAPI();
      expect(session.isLoggedIn, isTrue);
    });
  });

  group('M07 owner sign-up', () {
    OwnerSignupController signup() =>
        OwnerSignupController(repository: repo, session: session, speech: speech, translation: translation);

    test('the password rules say what is missing', () {
      final c = signup()..onPasswordChanged('abc12');
      expect(c.passwordStrong, isFalse);
      expect(c.strength, 2);
      expect(c.rules.map((r) => (r.label, r.met)), [('8 or more characters', false), ('A number', true)]);
      expect(c.passwordHasError, isFalse); // not while typing
      c.onPasswordDone();
      expect(c.passwordHasError, isTrue);
      c.onPasswordChanged('12345678');
      expect(c.rules.last.label, 'A letter');
      c.onPasswordChanged('abcd1234');
      expect(c.passwordStrong, isTrue);
      expect(c.passwordHasError, isFalse);
    });

    test('tapping Next on an empty form marks every missing part', () {
      final c = signup()..onDisabledNextTap();
      expect(c.nameError, 'Add your name');
      expect(c.emailError, isNotNull);
      expect(c.showPasswordRules.value, isTrue);
      expect(c.showTermsError.value, isTrue);
      c.onAgreeChanged(true);
      expect(c.showTermsError.value, isFalse);
    });

    test('an email that already has an account offers to log in instead', () async {
      when(() => repo.registerOwner(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => const ApiFailure<SessionOutModel>(ApiException(code: 'email_taken', message: '')));
      final c = signup()
        ..onNameChanged('Suresh Shah')
        ..onEmailChanged('suresh@brightair.example')
        ..onPasswordChanged('abcd1234')
        ..onAgreeChanged(true);
      expect(c.canSubmit, isTrue);
      await c.callRegisterAPI();
      expect(c.emailError, 'This email already has an account.');
      expect(c.canSubmit, isFalse);
      c.onEmailChanged('suresh2@brightair.example');
      expect(c.emailError, isNull);
    });

    test('creating the account signs the owner in, once', () async {
      final owner = me(name: 'Suresh Shah', phone: null, email: 'suresh@brightair.example');
      when(() => repo.registerOwner(
            name: any(named: 'name'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => ApiSuccess<SessionOutModel>(session_(user: owner)));
      when(() => repo.updateProfile(name: any(named: 'name'))).thenAnswer((_) async => ApiSuccess<MeOutModel>(owner));
      final c = signup()
        ..onNameChanged('Suresh Shah')
        ..onEmailChanged('Suresh@BrightAir.example')
        ..onPasswordChanged('abcd1234')
        ..onAgreeChanged(true);
      await c.callRegisterAPI();
      expect(session.me.value?.email, 'suresh@brightair.example');
      expect(c.initials, 'SS');
      await c.callRegisterAPI(); // back from step 2 and Next again
      verify(() => repo.registerOwner(name: 'Suresh Shah', email: 'Suresh@BrightAir.example', password: 'abcd1234'))
          .called(1);
      verify(() => repo.updateProfile(name: 'Suresh Shah')).called(1);
    });
  });

  group('M07 company setup', () {
    late MockCompanyRepository companies;
    late MockFilesRepository files;
    late FakeImagePicker picker;

    CompanySetupController setup({ConfigService? config}) {
      session.me.value = me(name: 'Suresh Shah', phone: null, email: 'suresh@brightair.example');
      return CompanySetupController(
        companies: companies,
        files: files,
        session: session,
        config: config ?? _config(),
        picker: picker,
        speech: speech,
        translation: translation,
      )..onInit();
    }

    setUp(() {
      companies = MockCompanyRepository();
      files = MockFilesRepository();
      picker = FakeImagePicker();
    });

    test('with one trade it is chosen already, and the preview shows the owner', () {
      final c = setup()..onNameChanged('BrightAir Services');
      expect(c.trade.value?.key, 'hvac');
      expect(c.canSubmit, isTrue);
      expect(c.previewMeta, 'HVAC · India · Owner Suresh');
      expect(c.timezone, 'Asia/Kolkata');
    });

    test('missing name and trade are both explained', () {
      final c = setup(
        config: _config(trades: const [TradeOutModel(key: 'hvac', name: 'HVAC'), TradeOutModel(key: 'solar', name: 'Solar')]),
      );
      expect(c.trade.value, isNull);
      c.onDisabledCreateTap();
      expect(c.showNameError.value, isTrue);
      expect(c.showTradeError.value, isTrue);
    });

    test('creates the company, renews the session and adds the logo', () async {
      when(() => companies.createCompany(
            name: any(named: 'name'),
            trade: any(named: 'trade'),
            country: any(named: 'country'),
            timezone: any(named: 'timezone'),
          )).thenAnswer((_) async => const ApiSuccess<CompanyOutModel>(_company));
      when(() => repo.refreshSession()).thenAnswer((_) async => ApiSuccess<SessionOutModel>(session_()));
      when(() => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')))
          .thenAnswer((_) async => const ApiSuccess<String>('up-1'));
      when(() => companies.setLogo(any())).thenAnswer((_) async => const ApiSuccess<CompanyOutModel>(_company));

      final c = setup()..onNameChanged('BrightAir Services');
      c.country.value = _config().countries[1];
      c.logo.value = tinyJpeg;
      await c.callCreateCompanyAPI();

      verify(() => companies.createCompany(
            name: 'BrightAir Services',
            trade: 'hvac',
            country: 'US',
            timezone: 'America/New_York',
          )).called(1);
      verify(() => repo.refreshSession()).called(1);
      verify(() => files.upload(kind: UploadKind.logo, bytes: tinyJpeg.bytes, contentType: 'image/jpeg')).called(1);
      verify(() => companies.setLogo('up-1')).called(1);
    });
  });

  group('M08 forgot password', () {
    test('needs a valid email, then sends the link', () async {
      when(() => repo.forgotPassword(any())).thenAnswer((_) async => const ApiSuccess<void>(null));
      final c = ForgotPasswordController(repository: repo, speech: speech, translation: translation);
      c.onEmailChanged('priya@');
      c.onDisabledSendTap();
      expect(c.showEmailError.value, isTrue);
      c.onEmailChanged(' priya@brightair.example ');
      expect(c.showEmailError.value, isFalse);
      await c.callSendLinkAPI();
      verify(() => repo.forgotPassword(' priya@brightair.example ')).called(1);
    });

    test('check your email: send again waits a minute, then sends a new link', () async {
      when(() => repo.forgotPassword(any())).thenAnswer((_) async => const ApiSuccess<void>(null));
      final opened = <Uri>[];
      final c = CheckEmailController(
        repository: repo,
        email: 'priya@brightair.example',
        openUrl: (uri) async {
          opened.add(uri);
          return true;
        },
      )..onInit();
      expect(c.secondsLeft.value, 60);
      expect(c.waitText, '1:00');
      await c.callResendAPI();
      verifyNever(() => repo.forgotPassword(any()));
      await c.onOpenMailTap();
      expect(opened.single.scheme, 'mailto'); // tests run as Android/Linux
      c.onClose();
    });
  });

  group('M11 profile', () {
    test('saves the name, the work and a new photo', () async {
      final files = MockFilesRepository();
      session.me.value = me();
      when(() => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')))
          .thenAnswer((_) async => const ApiSuccess<String>('up-9'));
      when(() => repo.updateProfile(
            name: any(named: 'name'),
            trade: any(named: 'trade'),
            avatarUploadId: any(named: 'avatarUploadId'),
          )).thenAnswer((_) async => ApiSuccess<MeOutModel>(me(trade: 'hvac')));
      when(() => repo.refreshSession()).thenAnswer((_) async => ApiSuccess<SessionOutModel>(session_()));
      final c = ProfileSetupController(
        repository: repo,
        files: files,
        picker: FakeImagePicker(),
        session: session,
        config: _config(),
        speech: speech,
        translation: translation,
      )..onInit();
      c.photo.value = tinyJpeg;
      await c.callSaveProfileAPI();
      verify(() => files.upload(kind: UploadKind.avatar, bytes: tinyJpeg.bytes, contentType: 'image/jpeg')).called(1);
      verify(() => repo.updateProfile(name: 'Ramesh Patel', trade: 'hvac', avatarUploadId: 'up-9')).called(1);
    });
  });
}

SessionOutModel session_({MeOutModel? user}) => session(user: user);
