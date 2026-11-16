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
import 'package:kaamnishaan/UI/screens/home_section/dashboard_section/dashboard_controller.dart';
import 'package:kaamnishaan/UI/screens/home_section/home_shell_section/home_shell_controller.dart';
import 'package:kaamnishaan/UI/screens/home_section/home_shell_section/home_shell_screen.dart';
import 'package:kaamnishaan/UI/screens/home_section/today_section/today_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/camera_section/camera_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/camera_section/camera_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/capture_hub_section/capture_hub_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/capture_hub_section/capture_hub_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_details_section/job_details_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_details_section/job_details_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_list_section/job_list_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_list_section/job_list_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_details_section/photo_details_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_details_section/photo_details_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_gallery_section/photo_gallery_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_gallery_section/photo_gallery_screen.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_pair_section/photo_pair_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_pair_section/photo_pair_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/intro_section/intro_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/intro_section/intro_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/language_section/language_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/language_section/language_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/splash_section/splash_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/splash_section/splash_screen.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/welcome_section/welcome_controller.dart';
import 'package:kaamnishaan/UI/screens/onboarding_section/welcome_section/welcome_screen.dart';
import 'package:kaamnishaan/UI/theme/kn_app_theme.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
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
  Future<void> today(WidgetTester t, String name, ApiResult<TodayModel> answer, {TodayModel? saved, bool dark = false}) async {
    final home = MockHomeRepository();
    when(() => home.today()).thenAnswer((_) async => answer);
    session.me.value = me(name: 'Ramesh Patel');
    if (saved != null) await prefs.setCachedToday('u1', jsonEncode(saved.toJson()));
    Get.put(HomeShellController(session: session));
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
    Get.put(jobList(const []));
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
      QuestionOutModel(
        id: 'q3', position: 3, type: 'yes_no', text: 'Is the air filter clean?', translationStatus: 'ready', options: const [],
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
