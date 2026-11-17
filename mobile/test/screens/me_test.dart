import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/me_section/language_settings_section/language_settings_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/me_section/me_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/my_reports_section/my_reports_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/waiting_to_send_section/waiting_to_send_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/photo_queue_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

/// Toasts and navigation need the app, which unit tests don't have.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late MockFilesRepository files;
  late PhotoQueueService queue;
  late MockMeRepository me;
  late SessionService session;
  late TranslationService translation;

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
    tmp = Directory.systemTemp.createTempSync('kn_me_');
    files = MockFilesRepository();
    // no internet: everything stays on the phone
    when(() => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')))
        .thenAnswer((_) async => const ApiFailure<String>(ApiException(code: 'no_internet', message: '')));
    queue = await PhotoQueueService(
      files: files,
      jobs: MockJobsRepository(),
      folder: () async => Directory('${tmp.path}/pending'),
      retryEvery: const Duration(hours: 1),
    ).init();
    me = MockMeRepository();
    session = SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository());
  });

  tearDown(() {
    queue.onClose();
    tmp.deleteSync(recursive: true);
  });

  String photoFile(String name) => (File('${tmp.path}/$name.jpg')..writeAsBytesSync(const [1, 2, 3])).path;

  test('M37 counts and the number of things waiting to send', () async {
    session.me.value = profileOf('technician');
    when(me.stats).thenAnswer(
      (_) async => const ApiSuccess<MeStatsModel>(MeStatsModel(jobsDone: 14, photos: 96, reportsSent: 12)),
    );
    final c = MeController(me: me, session: session, translation: translation, queue: queue);
    await c.load();
    expect(c.numbers.map((s) => '${s.value} ${s.label}'), ['14 Jobs done', '96 Photos', '12 Reports']);
    expect(c.waiting, 0);
    await queue.add(jobId: 'j1', stage: 'after', sourcePath: photoFile('a'), customer: 'Green Valley Clinic');
    await queue.addTyped(jobId: 'j1', text: 'Cleaned the filter');
    expect(c.waiting, 2);
    expect(c.languageName, 'English');
    session.me.value = profileOf('owner');
    when(me.stats).thenAnswer(
      (_) async =>
          const ApiSuccess<MeStatsModel>(MeStatsModel(jobsDone: 0, photos: 0, reportsSent: 40, team: 6, customers: 31)),
    );
    await c.load();
    expect(c.numbers.map((s) => s.label), ['Reports sent', 'Team', 'To review']);
  });

  test('M38 saves the language on the phone and on the account', () async {
    session.me.value = profileOf('technician');
    when(() => me.setLanguage(any())).thenAnswer((_) async => ApiSuccess<MeOutModel>(profileOf('technician')));
    final c = LanguageSettingsController(me: me, session: session, translation: translation);
    expect(c.reportLanguage, 'English');
    c.onLanguageTap('hi');
    expect(c.changed, isTrue);
    await _ignoreApp(c.onSaveTap);
    verify(() => me.setLanguage('hi')).called(1);
    expect(translation.prefs.languageCode, 'hi'); // kept on the phone
  });

  test('M30 filters ask the server for the right states', () async {
    when(() => me.myReports(statuses: any(named: 'statuses'), period: any(named: 'period'), cursor: any(named: 'cursor')))
        .thenAnswer(
      (_) async => const ApiSuccess<ReportListModel>(
        ReportListModel(data: [], meta: ListMetaModel(counts: {'all': 3, 'pending_review': 1})),
      ),
    );
    final c = MyReportsController(me: me, translation: translation);
    await c.load();
    expect(c.filterLabel(ReportFilter.all), 'All 3');
    c.onFilterTap(ReportFilter.approved);
    await Future<void>.delayed(Duration.zero);
    verify(() => me.myReports(statuses: ['approved', 'shared', 'acknowledged'])).called(1);
    c.onFilterTap(ReportFilter.changes);
    await Future<void>.delayed(Duration.zero);
    verify(() => me.myReports(statuses: ['changes_requested'])).called(1);
  });

  group('M43 waiting to send', () {
    test('lists photos and notes newest first, and how many were not sent', () async {
      await queue.add(
        jobId: 'j1',
        stage: 'after',
        sourcePath: photoFile('a'),
        takenAt: DateTime(2026, 10, 31, 11, 41),
        customer: 'Green Valley Clinic',
      );
      final old = await queue.add(
        jobId: 'j2',
        stage: 'during',
        sourcePath: photoFile('b'),
        takenAt: DateTime(2026, 10, 30, 15, 2),
        customer: 'Mehta house',
      );
      await queue.addTyped(jobId: 'j1', text: 'Cleaned the filter', customer: 'Green Valley Clinic');
      old.state = PendingState.failed;
      final c = WaitingToSendController(queue: queue, translation: translation)..onInit();
      final items = c.items;
      expect(items.map((i) => i.title), ['Typed note', 'After photo', 'During photo']);
      expect(items[1].subtitle, startsWith('Green Valley Clinic · 11:41'));
      expect(c.summary, '3 items · 1 not sent');
      expect(c.allSent, isFalse);
      c.onClose();
    });

    test('"Send all now" gives "Not sent" items a fresh start; without internet it says so', () async {
      final p = await queue.add(jobId: 'j1', stage: 'after', sourcePath: photoFile('a'));
      p
        ..state = PendingState.failed
        ..tries = 6;
      final c = WaitingToSendController(queue: queue, translation: translation)..onInit();
      await _ignoreApp(c.onSendAllTap);
      expect(queue.items.single.state, PendingState.waiting);
      expect(queue.items.single.tries, 0);
      c.onClose();
    });

    test('everything sent: counts what went', () async {
      final c = WaitingToSendController(queue: queue, translation: translation)..onInit();
      queue.sent.value++;
      queue.notesSent.value++;
      await Future<void>.delayed(Duration.zero);
      expect(c.allSent, isTrue);
      expect(c.sentCount, 2);
      expect(c.sentDetail, '1 photo · 1 note');
      c.onClose();
    });
  });

  test('the customer name is kept with each item across a restart', () async {
    await queue.add(jobId: 'j1', stage: 'before', sourcePath: photoFile('a'), customer: 'Green Valley Clinic');
    await queue.addTyped(jobId: 'j1', text: 'Note', customer: 'Green Valley Clinic');
    queue.onClose();
    queue = await PhotoQueueService(
      files: files,
      jobs: MockJobsRepository(),
      folder: () async => Directory('${tmp.path}/pending'),
      retryEvery: const Duration(hours: 1),
    ).init();
    expect(queue.items.single.customer, 'Green Valley Clinic');
    expect(queue.notes.single.customer, 'Green Valley Clinic');
    expect(queue.total, 2);
  });
}

MeOutModel profileOf(String role) => MeOutModel(
      id: 'u1',
      name: 'Ramesh Patel',
      emailVerified: true,
      appLanguage: 'en',
      theme: 'system',
      role: role,
      company: const CompanyOutModel(
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
      permissions: const [],
    );
