@Tags(['screenshots'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/common_widgets/kn_otp_boxes.dart';
import 'package:kaamnishaan/UI/screens/auth_section/check_email_section/check_email_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/check_email_section/check_email_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/company_setup_section/company_setup_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/company_setup_section/company_setup_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/email_login_section/email_login_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/email_login_section/email_login_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/forgot_password_section/forgot_password_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/forgot_password_section/forgot_password_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/join_company_section/join_company_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/join_company_section/join_company_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/otp_section/otp_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/otp_section/otp_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/owner_signup_section/owner_signup_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/owner_signup_section/owner_signup_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/phone_section/phone_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/phone_section/phone_screen.dart';
import 'package:kaamnishaan/UI/screens/auth_section/profile_setup_section/profile_setup_controller.dart';
import 'package:kaamnishaan/UI/screens/auth_section/profile_setup_section/profile_setup_screen.dart';
import 'package:kaamnishaan/UI/screens/checklists_section/checklist_question_section/checklist_question_controller.dart';
import 'package:kaamnishaan/UI/screens/checklists_section/checklist_question_section/checklist_question_screen.dart';
import 'package:kaamnishaan/UI/screens/checklists_section/checklists_section/checklists_controller.dart';
import 'package:kaamnishaan/UI/screens/checklists_section/checklists_section/checklists_screen.dart';
import 'package:kaamnishaan/UI/screens/customer_section/customer_details_section/customer_details_controller.dart';
import 'package:kaamnishaan/UI/screens/customer_section/customer_details_section/customer_details_screen.dart';
import 'package:kaamnishaan/UI/screens/home_section/dashboard_section/dashboard_controller.dart';
import 'package:kaamnishaan/UI/screens/home_section/home_shell_section/home_shell_controller.dart';
import 'package:kaamnishaan/UI/screens/home_section/home_shell_section/home_shell_screen.dart';
import 'package:kaamnishaan/UI/screens/home_section/today_section/today_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/assign_technician_section/assign_technician_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/assign_technician_section/assign_technician_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/camera_section/camera_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/camera_section/camera_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/capture_hub_section/capture_hub_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/capture_hub_section/capture_hub_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_details_section/job_details_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_details_section/job_details_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_list_section/job_list_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_list_section/job_list_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/new_job_section/new_job_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/new_job_section/new_job_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_details_section/photo_details_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_details_section/photo_details_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_gallery_section/photo_gallery_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_gallery_section/photo_gallery_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_pair_section/photo_pair_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_pair_section/photo_pair_screen.dart';
import 'package:kaamnishaan/UI/screens/me_section/company_settings_section/company_settings_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/company_settings_section/company_settings_screen.dart';
import 'package:kaamnishaan/UI/screens/me_section/language_settings_section/language_settings_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/language_settings_section/language_settings_screen.dart';
import 'package:kaamnishaan/UI/screens/me_section/me_section/me_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/me_section/me_tab.dart';
import 'package:kaamnishaan/UI/screens/me_section/messages_section/messages_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/messages_section/messages_screen.dart';
import 'package:kaamnishaan/UI/screens/me_section/my_reports_section/my_reports_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/my_reports_section/my_reports_screen.dart';
import 'package:kaamnishaan/UI/screens/me_section/waiting_to_send_section/waiting_to_send_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/waiting_to_send_section/waiting_to_send_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/intro_section/intro_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/intro_section/intro_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/language_section/language_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/language_section/language_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/splash_section/splash_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/splash_section/splash_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/welcome_section/welcome_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/welcome_section/welcome_screen.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_draft_section/report_draft_controller.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_draft_section/report_draft_screen.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_editor_section/report_editor_controller.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_editor_section/report_editor_screen.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_making_section/report_making_controller.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_making_section/report_making_screen.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_sent_section/report_sent_controller.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_sent_section/report_sent_screen.dart';
import 'package:kaamnishaan/UI/screens/review_section/report_pdf_section/report_pdf_controller.dart';
import 'package:kaamnishaan/UI/screens/review_section/report_pdf_section/report_pdf_screen.dart';
import 'package:kaamnishaan/UI/screens/review_section/report_review_section/report_review_controller.dart';
import 'package:kaamnishaan/UI/screens/review_section/report_review_section/report_review_screen.dart';
import 'package:kaamnishaan/UI/screens/review_section/review_queue_section/review_queue_controller.dart';
import 'package:kaamnishaan/UI/screens/review_section/review_queue_section/review_queue_tab.dart';
import 'package:kaamnishaan/UI/screens/review_section/share_report_section/share_report_controller.dart';
import 'package:kaamnishaan/UI/screens/review_section/share_report_section/share_report_screen.dart';
import 'package:kaamnishaan/UI/screens/team_section/invite_section/invite_controller.dart';
import 'package:kaamnishaan/UI/screens/team_section/invite_section/invite_screen.dart';
import 'package:kaamnishaan/UI/screens/team_section/team_section/team_controller.dart';
import 'package:kaamnishaan/UI/screens/team_section/team_section/team_screen.dart';
import 'package:kaamnishaan/UI/screens/voice_section/voice_note_section/voice_note_controller.dart';
import 'package:kaamnishaan/UI/screens/voice_section/voice_note_section/voice_note_screen.dart';
import 'package:kaamnishaan/UI/screens/voice_section/voice_notes_section/voice_notes_controller.dart';
import 'package:kaamnishaan/UI/screens/voice_section/voice_notes_section/voice_notes_screen.dart';
import 'package:kaamnishaan/UI/screens/voice_section/voice_record_section/voice_record_controller.dart';
import 'package:kaamnishaan/UI/screens/voice_section/voice_record_section/voice_record_screen.dart';
import 'package:kaamnishaan/UI/theme/kn_app_theme.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/audio_service.dart';
import 'package:kaamnishaan/infrastructure/services/camera_service.dart';
import 'package:kaamnishaan/infrastructure/services/config_service.dart';
import 'package:kaamnishaan/infrastructure/services/photo_queue_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:kaamnishaan/infrastructure/shared/job_arguments.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

class _StaticSplash extends SplashController {
  _StaticSplash({required super.session, required super.config, required super.prefs, required super.translation});

  @override
  Future<void> startApp() async => version.value = '0.1.0';
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Noto Sans', ['assets/fonts/NotoSans-Regular.ttf', 'assets/fonts/NotoSans-SemiBold.ttf', 'assets/fonts/NotoSans-Bold.ttf']);
  await load('Noto Sans Devanagari', ['assets/fonts/NotoSansDevanagari-Regular.ttf', 'assets/fonts/NotoSansDevanagari-SemiBold.ttf']);
  await load('Noto Sans Gujarati', ['assets/fonts/NotoSansGujarati-Regular.ttf', 'assets/fonts/NotoSansGujarati-SemiBold.ttf']);
  await load('Baloo 2', ['assets/fonts/Baloo2-Variable.ttf']);
  await load('DM Sans', ['assets/fonts/DMSans-Variable.ttf']);
  // the Lucide icon fonts (one per stroke weight) from the pub cache
  final cache = Directory('${Platform.environment['PUB_CACHE'] ?? '${Platform.environment['HOME']}/.pub-cache'}/hosted');
  final ttfs = cache
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.contains('lucide_icons_flutter') && f.path.endsWith('.ttf'))
      .toList();
  // ignore: avoid_print
  print('lucide fonts: ${ttfs.map((f) => f.uri.pathSegments.last).join(', ')}');
  final icon = LucideIcons.check;
  final family = icon.fontPackage == null ? icon.fontFamily! : 'packages/${icon.fontPackage}/${icon.fontFamily}';
  // ignore: avoid_print
  print('lucide family: $family');
  // the app's icons use the standard font (2 px stroke), not the variable weight files
  await load(family, [ttfs.firstWhere((f) => f.uri.pathSegments.last == 'lucide.ttf').path]);
}

void main() {
  late PreferencesService prefs;
  late MockAuthRepository repo;
  late SessionService session;
  late ConfigService config;

  setUpAll(() async {
    registerFallbackValue(const JobQuery());
    registerFallbackValue(UploadKind.photo);
    registerFallbackValue(<int>[]);
    registerFallbackValue(DateTime(2026));
    await initializeDateFormatting();
    await _loadFonts();
  });

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    repo = MockAuthRepository();
    session = SessionService(tokens: MemoryTokenStorage(), repository: repo);
    config = ConfigService(MockConfigRepository())
      ..config.value = const ConfigOutModel(
        languages: [],
        countries: [
          CountryOutModel(code: 'IN', name: 'India', dialCode: '+91', flag: '🇮🇳'),
          CountryOutModel(code: 'US', name: 'United States', dialCode: '+1', flag: '🇺🇸'),
        ],
        trades: [TradeOutModel(key: 'hvac', name: 'AC and cooling (HVAC)')],
        defaultCountry: 'IN',
        passwordMinLength: 8,
        minAppVersion: '0.1.0',
        maintenance: false,
        features: {},
      );
  });

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget screen, {
    Locale locale = const Locale('en', 'IN'),
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        debugShowCheckedModeBanner: false,
        translations: KnTranslations(),
        locale: locale,
        fallbackLocale: const Locale('en', 'IN'),
        theme: KnTheme.light(locale),
        darkTheme: KnTheme.dark(locale),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: screen,
      ),
    );
    for (final asset in ['assets/images/onboarding_photos.jpg', 'assets/images/welcome_invite.jpg']) {
      await tester.runAsync(() => precacheImage(AssetImage(asset), tester.element(find.byType(Scaffold).first)));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await expectLater(find.byType(GetMaterialApp), matchesGoldenFile('out/$name.png'));
    Get.deleteAll(force: true); // stops screen timers (the code countdown)
  }

  TranslationService translation() => TranslationService(prefs);

  testWidgets('M01 splash', (t) async {
    Get.put<SplashController>(_StaticSplash(session: session, config: config, prefs: prefs, translation: translation()));
    await shot(t, 'm01_splash', const SplashScreen());
  });

  testWidgets('M02 language', (t) async {
    Get.put(LanguageController(translation: translation(), prefs: prefs, speech: FakeSpeech()));
    await shot(t, 'm02_language', const LanguageScreen());
  });

  testWidgets('M03 intro', (t) async {
    Get.put(IntroController(prefs: prefs));
    await shot(t, 'm03_intro_1', const IntroScreen());
  });

  testWidgets('M04 welcome', (t) async {
    Get.put(WelcomeController());
    await shot(t, 'm04_welcome', const WelcomeScreen());
  });

  PhoneController phone(String digits, {bool error = false}) {
    final c = PhoneController(repository: repo, config: config, speech: FakeSpeech(), translation: translation());
    c.country.value = config.countries[1];
    for (final d in digits.split('')) {
      c.onDigit(d);
    }
    if (error) c.onDisabledSendTap();
    return Get.put(c);
  }

  testWidgets('M05 phone', (t) async {
    phone('5550102233');
    await shot(t, 'm05_phone', const PhoneScreen());
  });

  testWidgets('M05 phone invalid', (t) async {
    phone('55501022', error: true);
    await shot(t, 'm05_phone_invalid', const PhoneScreen());
  });

  OtpController otp(String code, KnOtpState state, String message) {
    final c = OtpController(
      repository: repo,
      session: session,
      prefs: prefs,
      speech: FakeSpeech(),
      translation: translation(),
      args: OtpArguments(
        phone: '+15550102233',
        display: '+1 (555) 010-2233',
        sent: OtpSentModel(challengeId: 'c', resendAfter: 24, expiresAt: DateTime(2026)),
      ),
    );
    c.code.value = code;
    c.state.value = state;
    c.errorMessage.value = message;
    c.secondsLeft.value = state == KnOtpState.normal ? 24 : 0;
    return Get.put(c);
  }

  testWidgets('M05 code', (t) async {
    otp('472', KnOtpState.normal, '');
    await shot(t, 'm05_code', const OtpScreen());
  });

  testWidgets('M05 code wrong', (t) async {
    otp('4729', KnOtpState.error, 'Wrong code. 2 tries left.');
    await shot(t, 'm05_code_wrong', const OtpScreen());
  });

  testWidgets('M05 code expired', (t) async {
    otp('472', KnOtpState.expired, 'This code expired. Get a new one.');
    await shot(t, 'm05_code_expired', const OtpScreen());
  });

  JoinCompanyController join(String status) {
    session.invites.assignAll([invite(status: status)]);
    final c = JoinCompanyController(
      repository: repo,
      session: session,
      config: config,
      speech: FakeSpeech(),
      translation: translation(),
    );
    return Get.put(c);
  }

  testWidgets('M10 join', (t) async {
    join('pending');
    await shot(t, 'm10_join', const JoinCompanyScreen());
  });

  testWidgets('M10 join expired', (t) async {
    join('pending').state.value = JoinState.expired;
    await shot(t, 'm10_join_expired', const JoinCompanyScreen());
  });

  testWidgets('M11 profile', (t) async {
    session.me.value = me();
    Get.put(
      ProfileSetupController(
        repository: repo,
        files: MockFilesRepository(),
        picker: FakeImagePicker(),
        session: session,
        config: config,
        speech: FakeSpeech(),
        translation: translation(),
      ),
    );
    await shot(t, 'm11_profile', const ProfileSetupScreen());
  });

  EmailLoginController login({String email = 'priya@brightair.example', String password = 'secret1234'}) {
    final c = EmailLoginController(
      repository: repo,
      session: session,
      speech: FakeSpeech(),
      translation: translation(),
      clock: () => DateTime(2026, 11, 16, 10, 27),
    );
    c.emailController.text = email;
    c.passwordController.text = password;
    c.onEmailChanged(email);
    c.onPasswordChanged(password);
    return Get.put(c);
  }

  testWidgets('M06 login', (t) async {
    login();
    await shot(t, 'm06_login', const EmailLoginScreen());
  });

  testWidgets('M06 login wrong password', (t) async {
    login().attemptsLeft.value = 3;
    await shot(t, 'm06_login_wrong', const EmailLoginScreen());
  });

  testWidgets('M06 login invalid email', (t) async {
    login(email: 'priya@brightair').onDisabledLoginTap();
    await shot(t, 'm06_login_invalid', const EmailLoginScreen());
  });

  testWidgets('M06 login locked', (t) async {
    login().lock(DateTime(2026, 11, 16, 10, 42));
    await shot(t, 'm06_login_locked', const EmailLoginScreen());
  });

  OwnerSignupController signup({required String name, required String email, required String password}) {
    final c = OwnerSignupController(repository: repo, session: session, speech: FakeSpeech(), translation: translation());
    c.nameController.text = name;
    c.emailController.text = email;
    c.passwordController.text = password;
    c.onNameChanged(name);
    c.onEmailChanged(email);
    c.onPasswordChanged(password);
    c.onAgreeChanged(true);
    return Get.put(c);
  }

  testWidgets('M07 sign-up', (t) async {
    signup(name: 'Suresh Shah', email: 'suresh@brightair.example', password: 'abcd1234');
    await shot(t, 'm07_signup', const OwnerSignupScreen());
  });

  testWidgets('M07 sign-up email used and weak password', (t) async {
    final c = signup(name: 'Suresh Shah', email: 'suresh@brightair.example', password: 'abc12');
    c.emailTaken.value = true;
    c.onPasswordDone();
    await shot(t, 'm07_signup_weak', const OwnerSignupScreen());
  });

  CompanySetupController company({String name = ''}) {
    session.me.value = me(name: 'Suresh Shah', phone: null, email: 'suresh@brightair.example');
    final c = CompanySetupController(
      companies: MockCompanyRepository(),
      files: MockFilesRepository(),
      session: session,
      config: config,
      picker: FakeImagePicker(),
      speech: FakeSpeech(),
      translation: translation(),
    );
    c.nameController.text = name;
    c.onNameChanged(name);
    c.country.value = config.countries[1];
    return Get.put(c);
  }

  testWidgets('M07 company setup', (t) async {
    company(name: 'BrightAir Services');
    await shot(t, 'm07_company', const CompanySetupScreen());
  });

  testWidgets('M07 company setup missing details', (t) async {
    final c = company();
    c.trade.value = null;
    c.onDisabledCreateTap();
    await shot(t, 'm07_company_missing', const CompanySetupScreen());
  });

  testWidgets('M08 forgot password', (t) async {
    final c = ForgotPasswordController(repository: repo, speech: FakeSpeech(), translation: translation());
    c.emailController.text = 'priya@brightair.example';
    c.onEmailChanged('priya@brightair.example');
    Get.put(c);
    await shot(t, 'm08_forgot', const ForgotPasswordScreen());
  });

  testWidgets('M08 check your email', (t) async {
    Get.put(CheckEmailController(repository: repo, email: 'priya@brightair.example')).secondsLeft.value = 45;
    await shot(t, 'm08_check_email', const CheckEmailScreen());
  });

  JobListController jobList(List<JobListItemModel> found) {
    final jobs = MockJobsRepository();
    when(() => jobs.list(any())).thenAnswer(
      (_) async => ApiSuccess<JobListModel>(JobListModel(data: found, meta: const ListMetaModel())),
    );
    return JobListController(
      repository: jobs,
      session: session,
      translation: translation(),
      clock: () => DateTime(2026, 10, 31, 9),
      searchDelay: Duration.zero,
    );
  }

  // ---- Step 2c: home --------------------------------------------------------------------------
  /// The Me tab is in the shell for everyone (M37).
  MeController putMe({MeStatsModel stats = const MeStatsModel(jobsDone: 14, photos: 96, reportsSent: 12), PhotoQueueService? queue}) {
    final me = MockMeRepository();
    when(me.stats).thenAnswer((_) async => ApiSuccess<MeStatsModel>(stats));
    return Get.put(MeController(me: me, session: session, translation: translation(), queue: queue));
  }

  Future<void> today(WidgetTester t, String name, ApiResult<TodayModel> answer, {TodayModel? saved, bool dark = false}) async {
    final home = MockHomeRepository();
    when(() => home.today()).thenAnswer((_) async => answer);
    session.me.value = me(name: 'Ramesh Patel');
    if (saved != null) await prefs.setCachedToday('u1', jsonEncode(saved.toJson()));
    Get.put(HomeShellController(session: session));
    putMe();
    Get.put(
      TodayController(
        repository: home,
        session: session,
        prefs: prefs,
        translation: translation(),
        clock: () => DateTime(2026, 10, 31, 9, 15),
      ),
    );
    await shot(t, name, const HomeShellScreen(), dark: dark);
  }

  final busyDay = todayData(
    current: job(status: 'in_progress', proof: const ProofCountModel(done: 2, total: 5)),
    next: [
      job(id: 'j2', customer: 'Mehta house', title: 'AC service', at: DateTime(2026, 10, 31, 14)),
      job(id: 'j3', customer: 'Sharma residence', title: 'Filter change', status: 'completed', at: DateTime(2026, 10, 31, 9)),
    ],
  );

  testWidgets('M12 today', (t) async => today(t, 'm12_today', ApiSuccess<TodayModel>(busyDay)));

  testWidgets('M12 today dark', (t) async => today(t, 'm12_today_dark', ApiSuccess<TodayModel>(busyDay), dark: true));

  testWidgets('M12 today empty', (t) async {
    await today(
      t,
      'm12_today_empty',
      ApiSuccess<TodayModel>(todayData(manager: const ContactRefModel(name: 'Priya', phone: '+919800000000'))),
    );
  });

  testWidgets('M12 today offline', (t) async {
    await today(
      t,
      'm12_today_offline',
      const ApiFailure<TodayModel>(ApiException(code: 'no_internet', message: '')),
      saved: busyDay,
    );
  });

  Future<void> dashboard(WidgetTester t, String name, DashboardModel data, {List<ReportListItemModel> reviews = const []}) async {
    final home = MockHomeRepository();
    when(() => home.dashboard()).thenAnswer((_) async => ApiSuccess<DashboardModel>(data));
    when(() => home.reviewQueue(limit: any(named: 'limit'))).thenAnswer(
      (_) async => ApiSuccess<ReportListModel>(ReportListModel(data: reviews, meta: const ListMetaModel())),
    );
    session.me.value = const MeOutModel(
      id: 'u9',
      name: 'Priya Mehta',
      email: 'priya@brightair.example',
      emailVerified: true,
      appLanguage: 'en',
      theme: 'system',
      role: 'owner',
      company: CompanyOutModel(
        id: 'c1',
        name: 'BrightAir Services',
        country: 'IN',
        timezone: 'Asia/Kolkata',
        currency: 'INR',
        reportLanguage: 'en',
        plan: 'professional',
        status: 'trial',
        settings: CompanySettingsModel(),
      ),
      permissions: [],
    );
    Get.put(HomeShellController(session: session));
    putMe();
    Get.put(jobList(const []));
    final queue = MockReportsRepository();
    when(() => queue.list(statuses: any(named: 'statuses'), period: any(named: 'period'), q: any(named: 'q'), cursor: any(named: 'cursor')))
        .thenAnswer((_) async => const ApiSuccess<ReportListModel>(ReportListModel(data: [], meta: ListMetaModel())));
    Get.put(ReviewQueueController(reports: queue));
    Get.put(
      DashboardController(
        repository: home,
        session: session,
        translation: translation(),
        clock: () => DateTime(2026, 10, 31, 9, 30),
      ),
    );
    await shot(t, name, const HomeShellScreen());
  }

  testWidgets('M14 job list', (t) async {
    session.me.value = const MeOutModel(
      id: 'u9', name: 'Priya Mehta', emailVerified: true, appLanguage: 'en', theme: 'system', role: 'owner', permissions: [],
    );
    Get.put(
      jobList([
        job(status: 'in_progress', at: DateTime(2026, 10, 31, 11, 30)),
        job(id: 'j2', customer: 'Lake View Apartments', title: 'Duct cleaning', status: 'in_review', at: DateTime(2026, 10, 31, 10)),
        job(id: 'j3', customer: 'Mehta house', title: 'AC service', at: DateTime(2026, 10, 31, 14)),
        job(id: 'j4', customer: 'Sharma residence', title: 'Filter change', status: 'completed', at: DateTime(2026, 10, 31, 9)),
      ]),
    );
    await shot(t, 'm14_job_list', const JobListScreen());
  });

  testWidgets('M14 job list no results', (t) async {
    session.me.value = const MeOutModel(
      id: 'u9', name: 'Priya Mehta', emailVerified: true, appLanguage: 'en', theme: 'system', role: 'owner', permissions: [],
    );
    final c = Get.put(jobList(const []));
    c.searchController.text = 'Riverside';
    c.search.value = 'Riverside';
    c.filter.value = JobFilter.unassigned;
    await shot(t, 'm14_job_list_none', const JobListScreen());
  });

  testWidgets('M15 job details', (t) async {
    final jobs = MockJobsRepository();
    when(() => jobs.job(any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut()));
    session.me.value = me();
    Get.put(
      JobDetailsController(
        repository: jobs,
        session: session,
        speech: FakeSpeech(),
        translation: translation(),
        args: const JobArguments(id: 'j1', customer: 'Green Valley Clinic'),
        clock: () => DateTime(2026, 10, 31, 9),
      ),
    );
    await shot(t, 'm15_job_details', const JobDetailsScreen());
  });

  Future<void> hub(WidgetTester t, String name, ProofModel proof) async {
    final jobs = MockJobsRepository();
    when(() => jobs.proof(any())).thenAnswer((_) async => ApiSuccess<ProofModel>(proof));
    when(() => jobs.job(any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut(status: proof.status)));
    Get.put(
      CaptureHubController(
        repository: jobs,
        speech: FakeSpeech(),
        translation: translation(),
        args: const JobArguments(id: 'j1', customer: 'Green Valley Clinic', title: 'AC not cooling'),
      ),
    );
    await shot(t, name, const CaptureHubScreen());
  }

  testWidgets('M19 capture hub', (t) async => hub(t, 'm19_capture_hub', proofData()));

  testWidgets('M19 capture hub not started', (t) async {
    await hub(t, 'm19_capture_not_started', proofData(started: false, before: 0, during: 0));
  });

  // ---- Step 2e: camera and photos ------------------------------------------------------------
  EvidenceOutModel photo(String id, String stage, int h, int m, {String? slot}) => EvidenceOutModel(
        id: id,
        jobId: 'j1',
        stage: stage,
        shotSlot: slot,
        url: 'https://x/$id.jpg',
        size: 100,
        processing: 'ready',
        takenAt: DateTime(2026, 10, 31, h, m),
        takenBy: const PersonRefModel(id: 'u1', name: 'Ramesh'),
        locked: false,
        notesCount: 0,
      );

  Future<(MockJobsRepository, PhotoQueueService, Directory)> photoSetup(WidgetTester t) async {
    final tmp = Directory.systemTemp.createTempSync('kn_shot_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final jobs = MockJobsRepository();
    final files = MockFilesRepository();
    when(() => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')))
        .thenAnswer((_) async => const ApiFailure<String>(ApiException(code: 'no_internet', message: '')));
    when(() => jobs.evidence(any())).thenAnswer(
      (_) async => ApiSuccess<EvidenceListModel>(
        EvidenceListModel(
          data: [
            photo('e1', 'before', 10, 52),
            photo('e2', 'before', 10, 53),
            photo('e3', 'before', 10, 50),
            photo('e4', 'during', 11, 20),
            photo('e5', 'after', 11, 41),
          ],
          meta: const ListMetaModel(),
          pairs: const [],
        ),
      ),
    );
    final queue = (await t.runAsync(
      () => PhotoQueueService(
        files: files,
        jobs: jobs,
        folder: () async => Directory('${tmp.path}/pending'),
        retryEvery: const Duration(days: 1),
      ).init(),
    ))!;
    addTearDown(queue.onClose);
    return (jobs, queue, tmp);
  }

  testWidgets('M20 camera', (t) async {
    final (jobs, queue, tmp) = await photoSetup(t);
    await t.runAsync(() async {
      final f = File('${tmp.path}/x.jpg');
      File('assets/images/onboarding_photos.jpg').copySync(f.path);
      await queue.add(jobId: 'j1', stage: 'after', sourcePath: f.path);
    });
    Get.put(
      CameraScreenController(
        camera: FakeCamera(folder: tmp, previewAsset: 'assets/images/welcome_invite.jpg'),
        queue: queue,
        jobs: jobs,
        args: const PhotoArguments(
          jobId: 'j1',
          stage: 'after',
          prompts: [ShotPromptModel(stage: 'after', key: 'filter', prompt: 'Show the clean filter up close', done: false)],
        ),
      ),
    );
    await shot(t, 'm20_camera', const CameraScreen());
  });

  testWidgets('M20 camera off', (t) async {
    final (jobs, queue, tmp) = await photoSetup(t);
    Get.put(
      CameraScreenController(
        camera: FakeCamera(folder: tmp, result: CameraOpenResult.denied),
        queue: queue,
        jobs: jobs,
        args: const PhotoArguments(jobId: 'j1', stage: 'after'),
      ),
    );
    await shot(t, 'm20_camera_off', const CameraScreen());
  });

  testWidgets('M21 photo gallery', (t) async {
    final (jobs, queue, tmp) = await photoSetup(t);
    await t.runAsync(() async {
      final f = File('${tmp.path}/y.jpg');
      File('assets/images/onboarding_photos.jpg').copySync(f.path);
      await queue.add(jobId: 'j1', stage: 'after', sourcePath: f.path, takenAt: DateTime(2026, 10, 31, 11, 44));
    });
    Get.put(
      PhotoGalleryController(
        jobs: jobs,
        queue: queue,
        translation: translation(),
        args: const PhotoArguments(jobId: 'j1', stage: 'before', customer: 'Green Valley Clinic'),
      ),
    );
    await shot(t, 'm21_photo_gallery', const PhotoGalleryScreen());
  });

  // ---- Step 2f: before/after, photo details, checklists ----------------------------------------
  testWidgets('M22 before and after', (t) async {
    final (jobs, _, _) = await photoSetup(t);
    when(() => jobs.evidence(any())).thenAnswer(
      (_) async => ApiSuccess<EvidenceListModel>(
        EvidenceListModel(
          data: [
            photo('b1', 'before', 10, 52, slot: 'filter'),
            photo('a1', 'after', 11, 41, slot: 'filter'),
          ],
          meta: const ListMetaModel(),
          pairs: const [],
        ),
      ),
    );
    Get.put(
      PhotoPairController(
        jobs: jobs,
        translation: translation(),
        args: const PhotoDetailArguments(jobId: 'j1', customer: 'Green Valley Clinic', place: 'Room 2 · AC unit'),
      ),
    );
    await shot(t, 'm22_before_after', const PhotoPairScreen());
  });

  testWidgets('M23 photo details locked', (t) async {
    final jobs = MockJobsRepository();
    when(() => jobs.photo(any())).thenAnswer(
      (_) async => ApiSuccess<EvidenceDetailModel>(
        EvidenceDetailModel(
          id: 'b1',
          jobId: 'j1',
          stage: 'before',
          url: 'https://x/b1.jpg',
          size: 100,
          processing: 'ready',
          takenAt: DateTime(2026, 10, 31, 10, 52),
          takenBy: const PersonRefModel(id: 'u1', name: 'Ramesh Patel'),
          lat: 23.0225,
          lng: 72.5714,
          locked: true,
          lockedAt: DateTime(2026, 10, 31, 12, 5),
          notesCount: 1,
          canDelete: false,
          notes: [
            NoteOutModel(
              id: 'n1',
              author: const PersonRefModel(id: 'u1', name: 'Ramesh'),
              text: 'Filter blocked with dust. Cleaned and refitted.',
              createdAt: DateTime(2026, 10, 31, 10, 53),
            ),
          ],
        ),
      ),
    );
    Get.put(
      PhotoDetailsController(
        jobs: jobs,
        translation: translation(),
        args: const PhotoDetailArguments(jobId: 'j1', evidenceId: 'b1', customer: 'Green Valley Clinic', place: 'Room 2 · AC unit', index: 1, total: 3),
      ),
    );
    await shot(t, 'm23_photo_locked', const PhotoDetailsScreen());
  });

  testWidgets('M24 checklists', (t) async {
    final (_, queue, _) = await photoSetup(t);
    final checklists = MockChecklistsRepository();
    when(() => checklists.forJob(any())).thenAnswer(
      (_) async => ApiSuccess<JobChecklistListModel>(
        JobChecklistListModel(
          data: [
            JobChecklistItemModel(
              id: 'safe', templateId: 't1', name: 'Safety check', answered: 6, total: 6, status: 'done',
              completedAt: DateTime(2026, 10, 31, 10, 45),
            ),
            const JobChecklistItemModel(
              id: 'c1', templateId: 't2', name: 'HVAC service check', minutes: 5, answered: 0, total: 12, status: 'not_started',
            ),
          ],
          meta: const ListMetaModel(),
        ),
      ),
    );
    Get.put(
      ChecklistsController(
        checklists: checklists,
        queue: queue,
        translation: translation(),
        args: const ChecklistArguments(jobId: 'j1', customer: 'Green Valley Clinic', equipment: 'Split AC · Room 2'),
      ),
    );
    await shot(t, 'm24_checklists', const ChecklistsScreen());
  });

  Future<ChecklistQuestionController> questionSetup(WidgetTester t) async {
    final (_, queue, _) = await photoSetup(t);
    final checklists = MockChecklistsRepository();
    final qs = [
      question('q1', 1, answer: 'yes'),
      question('q2', 2, answer: 'pass', type: 'pass_fail'),
      const QuestionOutModel(
        id: 'q3', position: 3, type: 'yes_no', text: 'Is the air filter clean?', translationStatus: 'ready', options: [],
        photoRule: 'if_no', requiredValue: true, visible: true, photoNeeded: false,
        referenceImageUrl: 'https://x/filter.jpg',
      ),
      for (var i = 4; i <= 12; i++) question('q$i', i),
    ];
    when(() => checklists.submission(any())).thenAnswer(
      (_) async => ApiSuccess<SubmissionOutModel>(
        SubmissionOutModel(
          id: 'c1', jobId: 'j1', name: 'HVAC service check', language: 'en', answered: 2, total: 12,
          status: 'in_progress', locked: false, questions: qs,
        ),
      ),
    );
    final c = Get.put(
      ChecklistQuestionController(
        checklists: checklists,
        files: MockFilesRepository(),
        queue: queue,
        speech: FakeSpeech(),
        translation: translation(),
        args: const ChecklistArguments(jobId: 'j1', checklistId: 'c1', customer: 'Green Valley Clinic'),
      ),
    );
    await t.runAsync(c.load);
    return c;
  }

  testWidgets('M25 checklist question', (t) async {
    await questionSetup(t);
    await shot(t, 'm25_question', const ChecklistQuestionScreen());
  });

  testWidgets('M25 photo required', (t) async {
    final c = await questionSetup(t);
    await c.onChoose('no');
    await shot(t, 'm25_photo_required', const ChecklistQuestionScreen());
  });

  // ---- Step 2g: voice notes --------------------------------------------------------------------
  const voiceArgs = VoiceArguments(jobId: 'j1', customer: 'Green Valley Clinic');

  testWidgets('M27 voice recording', (t) async {
    final (_, queue, tmp) = await photoSetup(t);
    final c = Get.put(
      VoiceRecordController(recorder: FakeRecorder(), queue: queue, args: voiceArgs, temp: () async => tmp),
    );
    await t.pump(); // lets the recorder start
    c.elapsed.value = const Duration(seconds: 42);
    c.levels.assignAll([
      for (final v in [38, 40, 25, 19, 32, 29, 17, 11, 18, 31, 36, 24, 20, 37, 37, 24, 12, 11, 21, 29, 22, 20, 39, 42,
        29, 12, 18, 12, 19, 18, 19, 37, 44, 32, 12, 24, 23, 13, 14, 17, 32, 41, 33, 12, 29, 33, 23, 12])
        v / 44,
    ]);
    await shot(t, 'm27_voice_recording', const VoiceRecordScreen());
  });

  testWidgets('M27 microphone off', (t) async {
    final (_, queue, tmp) = await photoSetup(t);
    Get.put(
      VoiceRecordController(
        recorder: FakeRecorder(result: MicResult.denied),
        queue: queue,
        args: voiceArgs,
        temp: () async => tmp,
      ),
    );
    await shot(t, 'm27_voice_mic_off', const VoiceRecordScreen());
  });

  testWidgets('M28 voice notes', (t) async {
    final (_, queue, _) = await photoSetup(t);
    final voice = MockVoiceRepository();
    when(() => voice.notes(any())).thenAnswer(
      (_) async => ApiSuccess<VoiceNoteListModel>(
        VoiceNoteListModel(
          data: [
            noteItem('v1', excerpt: 'Filter in room 2 was full of dust. I cleaned it and added gas...'),
            noteItem('v2', status: 'transcribing', language: 'hi', duration: 18, minute: 5),
          ],
          meta: const ListMetaModel(),
        ),
      ),
    );
    Get.put(VoiceNotesController(voice: voice, queue: queue, player: FakePlayer(), args: voiceArgs));
    await shot(t, 'm28_voice_notes', const VoiceNotesScreen());
  });

  Future<void> transcript(WidgetTester t, String name, VoiceNoteOutModel n) async {
    final voice = MockVoiceRepository();
    when(() => voice.note(any())).thenAnswer((_) async => ApiSuccess<VoiceNoteOutModel>(n));
    Get.put(VoiceNoteController(voice: voice, player: FakePlayer(), args: voiceArgs.note(n.id, 1)));
    await shot(t, name, const VoiceNoteScreen());
  }

  testWidgets('M29 transcript', (t) async {
    await transcript(
      t,
      'm29_transcript',
      noteOut(
        'v1',
        text: 'The filter in room 2 was full of dust. I took it out, washed it and dried it. Gas was low, so I added '
            'refrigerant. After 15 minutes the room was cool, 22 degrees. The customer should clean the filter every month.',
      ),
    );
  });

  testWidgets('M29 not clear', (t) async {
    await transcript(t, 'm29_transcript_unclear', noteOut('v1', status: 'unclear', translatedTo: null));
  });

  // ---- Step 2h: the report --------------------------------------------------------------------
  const reportArgs = ReportArguments(
    jobId: 'j1',
    customer: 'Green Valley Clinic',
    reportId: 'r1',
    photos: 6,
    checklists: 2,
    notes: 2,
    thumbs: ['https://x/1.jpg', 'https://x/2.jpg', 'https://x/3.jpg', 'https://x/4.jpg'],
  );

  testWidgets('M31 making the report', (t) async {
    final reports = MockReportsRepository();
    final c = Get.put(ReportMakingController(reports: reports, args: reportArgs, autoStart: false));
    c.steps.assignAll({'collect_evidence': 'done', 'write_report': 'running', 'check_evidence': 'waiting'});
    await shot(t, 'm31_report_making', const ReportMakingScreen());
  });

  testWidgets('M31 could not make the report', (t) async {
    final reports = MockReportsRepository();
    Get.put(ReportMakingController(reports: reports, args: reportArgs, autoStart: false)).phase.value = MakePhase.failed;
    await shot(t, 'm31_report_failed', const ReportMakingScreen());
  });

  void reportSession() => session.me.value = const MeOutModel(
        id: 'u1',
        name: 'Ramesh Patel',
        emailVerified: true,
        appLanguage: 'en',
        theme: 'system',
        role: 'technician',
        company: CompanyOutModel(
          id: 'c1',
          name: 'BrightAir Services',
          country: 'IN',
          timezone: 'Asia/Kolkata',
          currency: 'INR',
          reportLanguage: 'en',
          plan: 'professional',
          status: 'trial',
          settings: CompanySettingsModel(),
        ),
        permissions: [],
      );

  testWidgets('M31 report draft', (t) async {
    reportSession();
    final reports = MockReportsRepository();
    final jobs = MockJobsRepository();
    when(() => reports.report(any())).thenAnswer(
      (_) async => ApiSuccess<ReportOutModel>(
        reportOut(
          summary: null,
          advice: null,
          workDone: 'Air filter in room 2 was blocked with dust. Cleaned and refitted it, refilled refrigerant and '
              'tested cooling for 15 minutes. Room now cools to 22°C.',
          flags: const [ReportFlagModel(kind: 'missing_evidence', text: 'after photo of outdoor unit')],
        ),
      ),
    );
    when(() => jobs.evidence(any())).thenAnswer(
      (_) async => ApiSuccess<EvidenceListModel>(
        EvidenceListModel(
          data: [photo('b1', 'before', 10, 52), photo('a1', 'after', 11, 41)],
          meta: const ListMetaModel(),
          pairs: const [],
        ),
      ),
    );
    Get.put(
      ReportDraftController(
        reports: reports,
        jobs: jobs,
        session: session,
        speech: FakeSpeech(),
        translation: translation(),
        args: reportArgs,
      ),
    );
    await shot(t, 'm31_report_draft', const ReportDraftScreen());
  });

  Future<void> editorShot(WidgetTester t, String name, {bool empty = false}) async {
    final reports = MockReportsRepository();
    when(() => reports.report(any())).thenAnswer(
      (_) async => ApiSuccess<ReportOutModel>(
        reportOut(
          workDone: 'Cleaned and refitted the air filter. Added refrigerant. Tested cooling for 15 minutes. Room now cools to 22°C.',
          advice: 'Clean the filter every month. Book the next service in 6 months.',
        ),
      ),
    );
    final c = Get.put(
      ReportEditorController(reports: reports, speech: FakeSpeech(), translation: translation(), args: reportArgs),
    );
    await t.pump();
    if (empty) c.parts[1].text.text = '';
    await shot(t, name, const ReportEditorScreen());
  }

  testWidgets('M32 report editor', (t) async => editorShot(t, 'm32_report_editor'));

  testWidgets('M32 report editor, part empty', (t) async => editorShot(t, 'm32_report_editor_empty', empty: true));

  testWidgets('M31 report sent', (t) async {
    final reports = MockReportsRepository();
    when(() => reports.report(any())).thenAnswer(
      (_) async => ApiSuccess<ReportOutModel>(reportOut(status: 'pending_review', actions: const [])),
    );
    Get.put(ReportSentController(reports: reports, translation: translation(), args: reportArgs));
    await shot(t, 'm31_report_sent', const ReportSentScreen());
  });

  // ---- Step 2i: Me ------------------------------------------------------------------------------
  void technicianWithCompany() => session.me.value = const MeOutModel(
        id: 'u1',
        name: 'Ramesh Patel',
        emailVerified: true,
        appLanguage: 'en',
        theme: 'system',
        role: 'technician',
        company: CompanyOutModel(
          id: 'c1',
          name: 'BrightAir Services',
          country: 'IN',
          timezone: 'Asia/Kolkata',
          currency: 'INR',
          reportLanguage: 'en',
          plan: 'professional',
          status: 'trial',
          settings: CompanySettingsModel(),
        ),
        permissions: [],
      );

  Future<void> waitingItems(WidgetTester t, PhotoQueueService queue, Directory tmp) => t.runAsync(() async {
        String file(String n) => (File('${tmp.path}/$n.jpg')..writeAsBytesSync(const [1, 2, 3])).path;
        await queue.add(
          jobId: 'j1',
          stage: 'after',
          sourcePath: file('a'),
          takenAt: DateTime(2026, 10, 31, 11, 41),
          customer: 'Green Valley Clinic',
        );
        await queue.addVoice(
          jobId: 'j1',
          sourcePath: (File('${tmp.path}/v.m4a')..writeAsBytesSync(const [1])).path,
          durationS: 18,
          recordedAt: DateTime(2026, 10, 31, 11, 45),
          customer: 'Green Valley Clinic',
        );
        final drain = await queue.add(
          jobId: 'j2',
          stage: 'during',
          sourcePath: file('d'),
          takenAt: DateTime(2026, 10, 30, 15, 2),
          customer: 'Mehta house',
        );
        drain.state = PendingState.failed;
        queue.items.refresh();
      });

  testWidgets('M37 Me', (t) async {
    final (_, queue, tmp) = await photoSetup(t);
    await waitingItems(t, queue, tmp);
    technicianWithCompany();
    final home = MockHomeRepository();
    when(() => home.today()).thenAnswer((_) async => ApiSuccess<TodayModel>(busyDay));
    Get.put(HomeShellController(session: session)).index.value = 1;
    Get.put(
      TodayController(
        repository: home,
        session: session,
        prefs: prefs,
        translation: translation(),
        clock: () => DateTime(2026, 10, 31, 9, 15),
      ),
    );
    putMe(queue: queue);
    await shot(t, 'm37_me', const HomeShellScreen());
  });

  testWidgets('M38 language settings', (t) async {
    technicianWithCompany();
    Get.put(LanguageSettingsController(me: MockMeRepository(), session: session, translation: translation()));
    await shot(t, 'm38_language', const LanguageSettingsScreen());
  });

  testWidgets('M30 my reports', (t) async {
    final me = MockMeRepository();
    ReportListItemModel item(String id, String customer, String title, String number, String status, int day, int h, int m,
            {String? note}) =>
        ReportListItemModel(
          id: id,
          number: number,
          status: status,
          changeNote: note,
          flags: 0,
          updatedAt: DateTime(2026, 10, day, h, m),
          submittedAt: DateTime(2026, 10, day, h, m),
          job: JobBriefModel(id: 'j$id', number: 'J-$id', title: title, customer: customer, status: 'in_review'),
        );
    when(() => me.myReports(statuses: any(named: 'statuses'), period: any(named: 'period'), cursor: any(named: 'cursor')))
        .thenAnswer(
      (_) async => ApiSuccess<ReportListModel>(
        ReportListModel(
          data: [
            item('1', 'Mehta house', 'AC service', 'R-1039', 'changes_requested', 30, 15, 10,
                note: 'Please add an after photo.'),
            item('2', 'Green Valley Clinic', 'AC not cooling', 'R-1042', 'pending_review', 31, 11, 58),
            item('3', 'Sharma residence', 'Filter change', 'R-1036', 'shared', 29, 9, 40),
          ],
          meta: const ListMetaModel(counts: {'all': 3, 'pending_review': 1, 'changes_requested': 1, 'shared': 1}),
        ),
      ),
    );
    Get.put(MyReportsController(me: me, translation: translation()));
    await shot(t, 'm30_my_reports', const MyReportsScreen());
  });

  testWidgets('M43 waiting to send', (t) async {
    final (_, queue, tmp) = await photoSetup(t);
    await waitingItems(t, queue, tmp);
    Get.put(WaitingToSendController(queue: queue, translation: translation()));
    await shot(t, 'm43_waiting_to_send', const WaitingToSendScreen());
  });

  testWidgets('M43 everything sent', (t) async {
    final (_, queue, _) = await photoSetup(t);
    final c = Get.put(WaitingToSendController(queue: queue, translation: translation()));
    c.sentPhotos.value = 2;
    c.sentNotes.value = 1;
    c.lastSent.value = DateTime(2026, 10, 31, 12, 4);
    await shot(t, 'm43_everything_sent', const WaitingToSendScreen());
  });

  // ---- Step 2j: messages ------------------------------------------------------------------------
  testWidgets('M42 messages', (t) async {
    final repo = MockNotificationsRepository();
    final at = DateTime(2026, 10, 31, 12, 10);
    NotificationOutModel m(String id, String kind, DateTime when, Map<String, dynamic> params,
            {bool read = false, String? actor}) =>
        NotificationOutModel(
          id: id,
          kind: kind,
          params: params,
          actor: actor == null ? null : PersonRefModel(id: 'm1', name: actor),
          jobId: 'j$id',
          reportId: 'r$id',
          coverUrl: 'https://x/$id.jpg',
          read: read,
          createdAt: when,
        );
    when(() => repo.list(cursor: any(named: 'cursor'), limit: any(named: 'limit'))).thenAnswer(
      (_) async => ApiSuccess<NotificationListModel>(
        NotificationListModel(
          data: [
            m('1', 'changes_requested', at.subtract(const Duration(minutes: 10)),
                {'customer': 'Mehta house', 'note': 'Please add an after photo.'}, actor: 'Priya Shah'),
            m('2', 'report_shared', at.subtract(const Duration(hours: 1)), {'customer': 'Sharma residence'}),
            m('3', 'job_assigned', DateTime(2026, 10, 31, 8, 5),
                {'customer': 'Green Valley Clinic', 'job': 'AC not cooling', 'scheduled_at': '2026-10-31T11:30:00'},
                read: true),
            m('4', 'report_approved', DateTime(2026, 10, 30, 17, 20), {'customer': 'Patel clinic'}, read: true),
          ],
          meta: const ListMetaModel(counts: {'unread': 2}),
        ),
      ),
    );
    when(() => repo.read(ids: any(named: 'ids'))).thenAnswer((_) async => const ApiSuccess<int>(0));
    Get.put(MessagesController(repository: repo, translation: translation(), clock: () => at));
    await shot(t, 'm42_messages', const MessagesScreen());
  });

  // ---- Step 2k: manager review ------------------------------------------------------------------
  final reviewAt = DateTime(2026, 10, 31, 12, 8);
  const reviewArgs = ReportArguments(jobId: 'j1', customer: 'Green Valley Clinic', reportId: 'r1');

  ReportListItemModel queueItem(String id, String customer, String title, String tech, int waiting, int photos) =>
      ReportListItemModel(
        id: id,
        number: 'R-$id',
        status: 'pending_review',
        draftedBy: 'ai',
        flags: 0,
        waitingMinutes: waiting,
        submittedAt: reviewAt.subtract(Duration(minutes: waiting)),
        updatedAt: reviewAt,
        thumbs: const ['https://x/1.jpg', 'https://x/2.jpg', 'https://x/3.jpg'],
        job: JobBriefModel(
          id: 'j$id',
          number: 'J-$id',
          title: title,
          customer: customer,
          status: 'in_review',
          photos: photos,
          technician: PersonRefModel(id: 'u$id', name: tech),
        ),
      );

  testWidgets('M30 review queue', (t) async {
    final reports = MockReportsRepository();
    when(() => reports.list(statuses: any(named: 'statuses'), period: any(named: 'period'), q: any(named: 'q'), cursor: any(named: 'cursor')))
        .thenAnswer((i) async {
      final statuses = i.namedArguments[#statuses] as List<String>?;
      if (statuses?.first == 'approved') {
        return ApiSuccess<ReportListModel>(
          ReportListModel(data: List.generate(5, (k) => queueItem('9$k', 'X', 'Y', 'Z', 0, 1)), meta: const ListMetaModel()),
        );
      }
      return ApiSuccess<ReportListModel>(
        ReportListModel(
          data: [
            queueItem('1041', 'Lake View Apartments', 'Duct cleaning', 'Carlos Diaz', 65, 9),
            queueItem('1042', 'Green Valley Clinic', 'AC not cooling', 'Ramesh Patel', 10, 6),
          ],
          meta: const ListMetaModel(counts: {'pending_review': 2}),
        ),
      );
    });
    Get.put(ReviewQueueController(reports: reports, clock: () => reviewAt));
    await shot(t, 'm30_review_queue', const Scaffold(body: ReviewQueueTab()));
  });

  testWidgets('M33 report review', (t) async {
    final reports = MockReportsRepository();
    final jobs = MockJobsRepository();
    when(() => reports.report(any())).thenAnswer(
      (_) async => ApiSuccess<ReportOutModel>(
        reportOut(
          status: 'pending_review',
          actions: const ['approve', 'request_changes', 'edit'],
          summary: null,
          advice: null,
          workDone: 'Cleaned the filter and coil. Topped up gas. Room 2 now cools to 22 °C.',
          flags: const [ReportFlagModel(kind: 'missing_evidence', text: 'drain pipe has a leak')],
        ),
      ),
    );
    when(() => jobs.evidence(any())).thenAnswer(
      (_) async => ApiSuccess<EvidenceListModel>(
        EvidenceListModel(
          data: [photo('b1', 'before', 10, 52), photo('a1', 'after', 11, 41), photo('d1', 'during', 11, 5)],
          meta: const ListMetaModel(),
          pairs: const [],
        ),
      ),
    );
    Get.put(ReportReviewController(reports: reports, jobs: jobs, translation: translation(), args: reviewArgs, clock: () => reviewAt));
    await shot(t, 'm33_report_review', const ReportReviewScreen());
  });

  Future<void> pdfShot(WidgetTester t, String name, PdfOutModel pdf) async {
    technicianWithCompany();
    final reports = MockReportsRepository();
    final jobs = MockJobsRepository();
    when(() => reports.report(any())).thenAnswer(
      (_) async => ApiSuccess<ReportOutModel>(
        reportOut(
          status: 'approved',
          summary: 'AC not cooling in room 2. Filter and coil were blocked with dust.',
          workDone: 'Cleaned the filter and coil. Topped up gas. Room now cools to 22 °C.',
        ),
      ),
    );
    when(() => jobs.evidence(any())).thenAnswer(
      (_) async => ApiSuccess<EvidenceListModel>(
        EvidenceListModel(data: [photo('b1', 'before', 10, 52), photo('a1', 'after', 11, 41)], meta: const ListMetaModel(), pairs: const []),
      ),
    );
    when(() => reports.pdf(any())).thenAnswer((_) async => ApiSuccess<PdfOutModel>(pdf));
    Get.put(
      ReportPdfController(
        reports: reports,
        jobs: jobs,
        session: session,
        translation: translation(),
        args: reviewArgs,
        pollEvery: const Duration(hours: 1),
      ),
    );
    await shot(t, name, const ReportPdfScreen());
  }

  testWidgets('M34 PDF', (t) async => pdfShot(
        t,
        'm34_pdf',
        const PdfOutModel(status: 'ready', filename: 'R-1042.pdf', pages: 3, size: 2400000, url: 'https://x/r.pdf'),
      ));

  testWidgets('M34 PDF building', (t) async => pdfShot(t, 'm34_pdf_building', const PdfOutModel(status: 'building', filename: 'R-1042.pdf')));

  Future<void> shareShot(WidgetTester t, String name, RecipientModel? to) async {
    final reports = MockReportsRepository();
    when(() => reports.share(any())).thenAnswer(
      (_) async => ApiSuccess<ShareInfoModel>(
        ShareInfoModel(
          reportId: 'r1',
          reportStatus: 'approved',
          canShare: true,
          recipient: to,
          channels: [
            ChannelOutModel(key: 'sms', available: to?.phone != null),
            const ChannelOutModel(key: 'whatsapp', available: true),
            ChannelOutModel(key: 'email', available: to?.email != null),
          ],
          link: ShareLinkOutModel(
            id: 'l1',
            url: 'https://kn.app/r/7GX2-QK',
            channel: 'copy',
            status: 'active',
            openCount: 0,
            createdAt: reviewAt,
            expiresAt: reviewAt.add(const Duration(days: 30)),
          ),
          sent: const [],
        ),
      ),
    );
    when(() => reports.pdf(any())).thenAnswer(
      (_) async => const ApiSuccess<PdfOutModel>(PdfOutModel(status: 'ready', filename: 'r.pdf', pages: 3, size: 2400000)),
    );
    when(() => reports.report(any())).thenAnswer(
      (_) async => ApiSuccess<ReportOutModel>(reportOut(status: 'approved')),
    );
    Get.put(ShareReportController(reports: reports, args: reviewArgs));
    await shot(t, name, const ShareReportScreen());
  }

  testWidgets('M35 share report', (t) async => shareShot(t, 'm35_share', const RecipientModel(name: 'Dr. Anita Rao', phone: '+1 555 010 0444')));

  testWidgets('M35 share report, no contact', (t) async => shareShot(t, 'm35_share_no_contact', const RecipientModel(name: 'Dr. Anita Rao')));

  // ---- Step 2l: new job and assign ----------------------------------------------------------------
  void ownerSession({String role = 'owner'}) => session.me.value = MeOutModel(
        id: 'u9',
        name: 'Priya Mehta',
        email: 'priya@brightair.example',
        emailVerified: true,
        appLanguage: 'en',
        theme: 'system',
        role: role,
        company: const CompanyOutModel(
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
        ),
        permissions: const [],
      );

  NewJobController putNewJob() {
    ownerSession();
    final customers = MockCustomersRepository();
    final checklists = MockChecklistsRepository();
    when(() => customers.search(any())).thenAnswer(
      (_) async => const ApiSuccess<CustomerListModel>(CustomerListModel(data: [], meta: ListMetaModel())),
    );
    when(() => checklists.templates()).thenAnswer(
      (_) async => const ApiSuccess<TemplateListModel>(
        TemplateListModel(
          data: [
            TemplateListItemModel(
              id: 't1', name: 'HVAC service check', questionCount: 12, status: 'published',
              needsTranslation: 0, scope: 'company', usageCount: 3, version: 1,
            ),
          ],
          meta: ListMetaModel(),
        ),
      ),
    );
    return Get.put(
      NewJobController(
        jobs: MockJobsRepository(),
        customers: customers,
        checklists: checklists,
        session: session,
        translation: translation(),
        clock: () => DateTime(2026, 10, 31, 9, 30),
      ),
    );
  }

  testWidgets('M16 new job', (t) async {
    final c = putNewJob();
    c.customer.value = const CustomerListItemModel(
      id: 'c1', name: 'Green Valley Clinic', jobCount: 4, site: SiteBriefModel(id: 's1', address: '4 Lake Road, Springfield'),
    );
    c.address.text = '4 Lake Road, Springfield';
    c.time.value = const TimeOfDay(hour: 11, minute: 30);
    c.work.text = 'AC not cooling in room 2';
    c.onWorkChanged(c.work.text);
    c.checklist.value = const TemplateListItemModel(
      id: 't1', name: 'HVAC service check', questionCount: 12, status: 'published',
      needsTranslation: 0, scope: 'company', usageCount: 3, version: 1,
    );
    await shot(t, 'm16_new_job', const NewJobScreen());
  });

  testWidgets('M16 new job, missing', (t) async {
    final c = putNewJob();
    c.work.text = 'AC not cooling in room 2';
    c.onWorkChanged(c.work.text);
    c.tried.value = true;
    await shot(t, 'm16_new_job_missing', const NewJobScreen());
  });

  Future<void> assignShot(WidgetTester t, String name, List<AssignableTechnicianModel> people) async {
    final jobs = MockJobsRepository();
    when(() => jobs.technicians(jobId: any(named: 'jobId'), at: any(named: 'at'))).thenAnswer(
      (_) async => ApiSuccess<AssignableListModel>(AssignableListModel(data: people, meta: const ListMetaModel())),
    );
    final c = Get.put(
      AssignTechnicianController(
        jobs: jobs,
        translation: translation(),
        clock: () => DateTime(2026, 10, 31, 9, 30),
        args: AssignArguments(customer: 'Green Valley Clinic', title: 'AC not cooling', at: DateTime(2026, 10, 31, 11, 30)),
      ),
    );
    if (people.isNotEmpty) c.picked.value = people.first.id;
    await shot(t, name, const AssignTechnicianScreen());
  }

  testWidgets('M17 assign technician', (t) async => assignShot(t, 'm17_assign', const [
        AssignableTechnicianModel(
          id: 'u1', name: 'Ramesh Patel', status: 'active', jobsToday: 3, capacity: 5, available: true, distanceKm: 1.1,
        ),
        AssignableTechnicianModel(
          id: 'u2', name: 'Carlos Ruiz', status: 'active', jobsToday: 2, capacity: 5, available: true, distanceKm: 4.8,
        ),
        AssignableTechnicianModel(
          id: 'u3', name: 'Arjun Desai', status: 'invited', jobsToday: 0, capacity: 5, available: false,
          disabledReason: 'invite_pending',
        ),
      ]));

  testWidgets('M17 assign, no technicians', (t) async => assignShot(t, 'm17_assign_empty', const []));

  // ---- Step 2m: team and invite --------------------------------------------------------------------
  testWidgets('M40 team', (t) async {
    ownerSession(role: 'manager');
    final repo = MockCompanyRepository();
    final at = DateTime.now().subtract(const Duration(days: 2));
    when(() => repo.team(role: any(named: 'role'), q: any(named: 'q'))).thenAnswer(
      (_) async => ApiSuccess<MemberListModel>(
        MemberListModel(
          data: [
            const MemberOutModel(id: 'u9', name: 'Priya Mehta', role: 'manager', status: 'active'),
            const MemberOutModel(
              id: 'u1', name: 'Ramesh Patel', role: 'technician', status: 'active', liveStatus: 'on_job', jobsToday: 3,
            ),
            const MemberOutModel(
              id: 'u2', name: 'Carlos Ruiz', role: 'technician', status: 'active', liveStatus: 'driving', jobsToday: 2,
            ),
            MemberOutModel(id: 'u3', name: 'Arjun Desai', role: 'technician', status: 'invited', inviteId: 'i3', invitedAt: at),
          ],
          meta: const ListMetaModel(),
        ),
      ),
    );
    Get.put(TeamController(company: repo, session: session));
    await shot(t, 'm40_team', const TeamScreen());
  });

  InviteController putInvite() {
    ownerSession(role: 'manager');
    final repo = MockCompanyRepository();
    when(() => repo.invitePreview()).thenAnswer(
      (_) async => const ApiSuccess<String>(
        'Priya from BrightAir Services invited you to KaamNishaan. Tap to join: kn.app/j/4KQ2',
      ),
    );
    final c = Get.put(InviteController(company: repo, config: config, session: session, translation: translation(), role: 'technician'));
    c.smsLanguage.value = 'en';
    c.phone.text = '98250 11111';
    c.onPhoneChanged(c.phone.text);
    c.name.text = 'Arjun Desai';
    c.onNameChanged(c.name.text);
    return c;
  }

  testWidgets('M40 invite', (t) async {
    putInvite();
    await shot(t, 'm40_invite', const InviteScreen());
  });

  testWidgets('M40 invite, number in team', (t) async {
    final c = putInvite();
    c.existingJoined.value = true;
    c.existingName.value = 'Carlos Ruiz';
    await shot(t, 'm40_invite_in_team', const InviteScreen());
  });

  // ---- Step 2n: customer details, company settings, manager Me -------------------------------------
  testWidgets('M18 customer details', (t) async {
    final repo = MockCustomersRepository();
    when(() => repo.customer(any())).thenAnswer(
      (_) async => ApiSuccess<CustomerOutModel>(
        CustomerOutModel(
          id: 'c1',
          name: 'Green Valley Clinic',
          customerSince: DateTime(2024, 3, 2),
          jobCount: 5,
          contacts: const [
            ContactOutModel(
              id: 'k1', name: 'Dr. Anita Rao', title: 'Clinic owner', isPrimary: true, reviewOptedOut: false,
              phone: '+1 555 010 0444', email: 'office@greenvalley.example',
            ),
          ],
          sites: const [SiteOutModel(id: 's1', addressLine1: '4 Lake Road', city: 'Springfield', country: 'US')],
          updatedAt: DateTime(2026, 10, 31),
          version: 1,
        ),
      ),
    );
    when(() => repo.jobs(any())).thenAnswer(
      (_) async => ApiSuccess<JobListModel>(
        JobListModel(
          data: [
            job(id: 'a', title: 'Filter change', status: 'completed', at: DateTime(2026, 8, 12)),
            job(id: 'b', title: 'Outdoor AC service', status: 'completed', at: DateTime(2026, 5, 3)),
            job(id: 'c', title: 'Gas refill', status: 'completed', at: DateTime(2026, 1, 9)),
          ],
          meta: const ListMetaModel(),
        ),
      ),
    );
    Get.put(
      CustomerDetailsController(
        customers: repo,
        translation: translation(),
        args: const CustomerArguments(id: 'c1', name: 'Green Valley Clinic'),
      ),
    );
    await shot(t, 'm18_customer', const CustomerDetailsScreen());
  });

  testWidgets('M39 company settings', (t) async {
    ownerSession();
    final repo = MockCompanyRepository();
    when(() => repo.plans(currency: any(named: 'currency'), locale: any(named: 'locale'))).thenAnswer(
      (_) async => const ApiSuccess<PlansOutModel>(
        PlansOutModel(
          currency: 'INR',
          trialDays: 14,
          creditPacks: [],
          creditRules: CreditRulesModel(),
          plans: [
            PlanOutModel(
              code: 'professional', name: 'Professional', price: MoneyModel(amount: 129900, currency: 'INR'),
              features: [], mostPopular: true,
            ),
          ],
        ),
      ),
    );
    Get.put(
      CompanySettingsController(
        companies: repo,
        files: MockFilesRepository(),
        session: session,
        config: config,
        picker: FakeImagePicker(),
        translation: translation(),
      ),
    );
    await shot(t, 'm39_company_settings', const CompanySettingsScreen());
  });

  testWidgets('M37 Me, manager', (t) async {
    ownerSession(role: 'manager');
    putMe(stats: const MeStatsModel(jobsDone: 0, photos: 0, reportsSent: 38, team: 4, customers: 24, toReview: 2));
    await shot(t, 'm37_me_manager', const Scaffold(body: MeTab()));
  });

  testWidgets('M13 dashboard', (t) async {
    await dashboard(t, 'm13_dashboard', dashboardData(), reviews: [reviewItem()]);
  });

  testWidgets('M13 dashboard new company', (t) async {
    await dashboard(t, 'm13_dashboard_new', dashboardData(teamInvited: false, firstJob: false, week: 0, lastWeek: 0));
  });

  testWidgets('M02 language in Hindi', (t) async {
    Get.put(LanguageController(translation: translation(), prefs: prefs, speech: FakeSpeech()));
    await shot(t, 'm02_language_hi', const LanguageScreen(), locale: const Locale('hi', 'IN'));
  });
}
