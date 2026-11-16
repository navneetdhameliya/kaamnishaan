import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/capture_hub_section/capture_hub_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_details_section/job_details_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_list_section/job_list_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:kaamnishaan/infrastructure/shared/job_arguments.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockJobsRepository jobs;
  late TranslationService translation;
  late SessionService session;
  late FakeSpeech speech;

  setUpAll(() async {
    await initializeDateFormatting();
    registerFallbackValue(const JobQuery());
  });

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    jobs = MockJobsRepository();
    speech = FakeSpeech();
    session = SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository())..me.value = me();
  });

  group('M14 job list', () {
    final queries = <JobQuery>[];

    JobListController list({String role = 'owner'}) {
      session.me.value = MeOutModel(
        id: 'u1',
        name: 'Priya Mehta',
        emailVerified: true,
        appLanguage: 'en',
        theme: 'system',
        role: role,
        permissions: const [],
      );
      queries.clear();
      when(() => jobs.list(any())).thenAnswer((inv) async {
        final q = inv.positionalArguments.first as JobQuery;
        queries.add(q);
        final found = (q.search ?? '').toLowerCase() == 'riverside' ? <JobListItemModel>[] : [job(), job(id: 'j2')];
        return ApiSuccess<JobListModel>(JobListModel(data: found, meta: const ListMetaModel()));
      });
      return JobListController(
        repository: jobs,
        session: session,
        translation: translation,
        clock: () => DateTime(2026, 10, 31, 9),
        searchDelay: Duration.zero,
      );
    }

    test('today first; tomorrow and unassigned (this week) ask the server again', () async {
      final c = list();
      await c.load();
      expect(queries.last.toQuery(), {'date': '2026-10-31', 'range': 'day', 'limit': 100});
      expect(c.subtitle, 'Sat, 31 Oct · 2 jobs today');
      c.onFilterTap(JobFilter.tomorrow);
      await Future<void>.delayed(Duration.zero);
      expect(queries.last.toQuery()['date'], '2026-11-01');
      c.onFilterTap(JobFilter.unassigned);
      await Future<void>.delayed(Duration.zero);
      expect(queries.last.toQuery(), {'date': '2026-10-31', 'range': 'week', 'unassigned': true, 'limit': 100});
      expect(c.subtitle, 'This week · 2 found');
      c.onClose();
    });

    test('search waits for typing to stop; Clear filters goes back to today', () async {
      final c = list();
      await c.load();
      c.onFilterTap(JobFilter.unassigned);
      c.onSearchChanged('Riverside');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(queries.last.toQuery()['q'], 'Riverside');
      expect(c.jobs, isEmpty);
      expect(c.hasFilters, isTrue);
      c.onClearFiltersTap();
      await Future<void>.delayed(Duration.zero);
      expect(c.filter.value, JobFilter.today);
      expect(queries.last.toQuery().containsKey('q'), isFalse);
      expect(c.jobs.length, 2);
      c.onClose();
    });

    test('technicians get no Unassigned chip and no names on rows', () {
      final c = list(role: 'technician');
      expect(c.filters, [JobFilter.today, JobFilter.tomorrow]);
      expect(c.showAssignee, isFalse);
      c.onClose();
    });
  });

  group('M15 job details', () {
    JobDetailsController details(JobOutModel j, {List<Uri>? opened}) {
      when(() => jobs.job(any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(j));
      return JobDetailsController(
        repository: jobs,
        session: session,
        speech: speech,
        translation: translation,
        args: const JobArguments(id: 'j1', customer: 'Green Valley Clinic'),
        clock: () => DateTime(2026, 10, 31, 9),
        openUrl: (uri) async {
          opened?.add(uri);
          return true;
        },
      );
    }

    test('shows when, where, the problem and the machine', () async {
      final c = details(jobOut());
      expect(c.customer, 'Green Valley Clinic'); // from the list, before loading
      await c.load();
      expect(c.when, startsWith('Today · 11:30'));
      expect(c.address, '4 Lake Road, Springfield');
      expect(c.problem, 'AC not cooling in room 2');
      expect(c.equipmentName, 'Split AC · 1.5 ton');
      expect(c.equipmentInfo, 'Room 2 · last service 12 Aug');
      expect(c.canStart, isTrue);
      expect(c.canContinue, isFalse);
    });

    test('Navigate opens maps to the site; Call phones the contact; the speaker reads it', () async {
      final opened = <Uri>[];
      final c = details(jobOut(), opened: opened);
      await c.load();
      await c.onNavigateTap();
      await c.onCallTap();
      expect(opened[0].toString(), 'https://www.google.com/maps/dir/?api=1&destination=21.17%2C72.83');
      expect(opened[1].toString(), 'tel:+919811122233');
      c.onSpeakTap();
      expect(speech.spoken.single, 'en:Green Valley Clinic. 4 Lake Road, Springfield. Problem: AC not cooling in room 2.');
    });

    test('a started job of mine offers Continue instead of Start', () async {
      final c = details(jobOut(status: 'in_progress', actions: const []));
      await c.load();
      expect(c.canStart, isFalse);
      expect(c.canContinue, isTrue);
    });

    test('Start job calls the server', () async {
      final c = details(jobOut());
      when(() => jobs.start(any())).thenAnswer(
        (_) async => const ApiFailure<JobOutModel>(ApiException(code: 'conflict', message: 'x')),
      );
      await c.load();
      when(() => jobs.start(any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut(status: 'in_progress')));
      await c.onStartTap();
      verify(() => jobs.start('j1')).called(1);
      expect(c.job.value?.status, 'in_progress');
    });
  });

  group('M19 capture hub', () {
    CaptureHubController hub(ProofModel proof) {
      when(() => jobs.proof(any())).thenAnswer((_) async => ApiSuccess<ProofModel>(proof));
      when(() => jobs.job(any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut(status: 'in_progress')));
      return CaptureHubController(
        repository: jobs,
        speech: speech,
        translation: translation,
        args: const JobArguments(id: 'j1'),
      );
    }

    test('counts the steps and points at the next one', () async {
      final c = hub(proofData());
      await c.load();
      expect(c.steps.map((s) => s.key), ['before', 'during', 'after', 'checklist', 'voice']);
      expect((c.doneCount, c.totalCount), (2, 5));
      expect(c.nextKey, 'after');
      expect(c.subline, '3 more steps, then make the report.');
      expect(c.unlockHint, 'Add after photos to unlock');
      expect(c.subtitle, 'AC not cooling · Room 2');
    });

    test('before the job starts everything waits, and Start job starts it', () async {
      final c = hub(proofData(started: false, before: 0, during: 0));
      await c.load();
      expect(c.notStarted, isTrue);
      expect(c.nextKey, isNull);
      expect(c.headline, 'Not started');
      when(() => jobs.start(any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut(status: 'in_progress')));
      when(() => jobs.proof(any())).thenAnswer((_) async => ApiSuccess<ProofModel>(proofData(before: 0, during: 0)));
      await c.onStartTap();
      expect(c.notStarted, isFalse);
      expect(c.nextKey, 'before');
    });

    test('a job without a checklist has 4 steps', () async {
      final p = proofData();
      final c = hub(
        ProofModel(
          jobId: 'j1',
          status: 'in_progress',
          steps: [
            for (final s in p.steps)
              s.key == 'checklist'
                  ? const ProofStepModel(key: 'checklist', count: 0, total: 0, requiredValue: false, done: false)
                  : s,
          ],
          canMakeReport: false,
          blockedBy: 'need_after_photo',
          locked: false,
        ),
      );
      await c.load();
      expect(c.totalCount, 4);
    });
  });
}
