import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/capture_hub_section/capture_hub_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_details_section/job_details_controller.dart';
import 'package:kaamnishaan/UI/screens/home_section/home_shell_section/home_shell_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_list_section/job_list_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/quick_job_section/quick_job_controller.dart';
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

  group('M14 filters sheet', () {
    test('a state and a technician narrow the list; the button shows how many are on', () async {
      session.me.value = const MeOutModel(
        id: 'u9', name: 'Priya Mehta', emailVerified: true, appLanguage: 'en', theme: 'system',
        role: 'manager', permissions: [],
      );
      final asked = <JobQuery>[];
      when(() => jobs.list(any())).thenAnswer((inv) async {
        asked.add(inv.positionalArguments.first as JobQuery);
        return const ApiSuccess<JobListModel>(JobListModel(data: [], meta: ListMetaModel()));
      });
      when(() => jobs.technicians(jobId: any(named: 'jobId'), at: any(named: 'at'))).thenAnswer(
        (_) async => const ApiSuccess<AssignableListModel>(
          AssignableListModel(data: [
            AssignableTechnicianModel(id: 't1', name: 'Ramesh Patel', status: 'active', available: true, capacity: 6, jobsToday: 2),
            AssignableTechnicianModel(id: 't2', name: 'Arjun Desai', status: 'invited', available: false, capacity: 6, jobsToday: 0),
          ], meta: ListMetaModel()),
        ),
      );
      final c = JobListController(
        repository: jobs, session: session, translation: translation, clock: () => DateTime(2026, 10, 31, 9),
      );
      await c.startFilters();
      expect([for (final t in c.technicians) t.name], ['Ramesh Patel']); // not joined: left out
      c.onDraftState(JobState.toCheck);
      c.onDraftTechnician('t1');
      expect(c.sheetFilters, 0); // nothing changes until "Show jobs"
      c.onApplyFilters();
      await Future<void>.delayed(Duration.zero);
      expect(asked.last.toQuery(), {
        'date': '2026-10-31', 'range': 'day', 'status': ['in_review'], 'assignee': 't1', 'limit': 100,
      });
      expect((c.sheetFilters, c.hasFilters, c.technicianName.value), (2, true, 'Ramesh Patel'));
      await c.startFilters();
      c.onDraftState(JobState.toCheck); // tapping the chosen one again clears it
      c.onApplyFilters();
      expect(c.sheetFilters, 1);
      c.onClearFiltersTap();
      await Future<void>.delayed(Duration.zero);
      expect((c.sheetFilters, asked.last.toQuery().containsKey('status')), (0, false));
      expect(JobListController.statesOf(JobState.going), ['in_progress', 'changes_requested']);
      c.onClose();
    });
  });

  group('M15 the office changes a job', () {
    JobDetailsController office(JobOutModel j) {
      when(() => jobs.job(any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(j));
      session.me.value = const MeOutModel(
        id: 'u9', name: 'Priya Mehta', emailVerified: true, appLanguage: 'en', theme: 'system',
        role: 'manager', permissions: [],
      );
      return JobDetailsController(
        repository: jobs,
        session: session,
        speech: speech,
        translation: translation,
        args: const JobArguments(id: 'j1', customer: 'Green Valley Clinic'),
        clock: () => DateTime(2026, 10, 31, 9),
      );
    }

    test('an unassigned job offers Assign as the main button and in the menu', () async {
      final c = office(jobOut(status: 'unassigned', assigneeId: null, actions: const ['edit', 'assign', 'cancel', 'delete']));
      await c.load();
      expect((c.hasMenu, c.showAssignButton, c.assignLabel), (true, true, 'Assign technician'));
      expect((c.canCancel, c.canDelete), (true, true));
    });

    test('an assigned job says Change technician; a technician sees no menu', () async {
      final c = office(jobOut(actions: const ['edit', 'assign', 'cancel', 'delete']));
      await c.load();
      expect((c.showAssignButton, c.assignLabel), (false, 'Change technician'));
      final t = office(jobOut());
      await t.load();
      expect(t.hasMenu, isFalse);
    });

    test('cancelling needs a reason, then shows the cancelled job', () async {
      when(() => jobs.cancel(any(), any())).thenAnswer(
        (_) async => ApiSuccess<JobOutModel>(jobOut(status: 'cancelled', actions: const [])),
      );
      final c = office(jobOut(actions: const ['assign', 'cancel']))..onInit();
      await c.load();
      c.startCancel();
      expect(c.canSendCancel, isFalse);
      expect(await c.onCancelJob(), isFalse);
      verifyNever(() => jobs.cancel(any(), any()));
      c.onCancelReasonPick(c.cancelReasons.first);
      expect((c.cancelReason.text, c.canSendCancel), ('Customer cancelled', true));
      c.cancelReason.text = 'Customer is away until Monday';
      expect(c.cancelDraft.value, 'Customer is away until Monday');
      var ok = false;
      await _quietRun(() async => ok = await c.onCancelJob());
      verify(() => jobs.cancel('j1', 'Customer is away until Monday')).called(1);
      expect((c.job.value!.status, c.hasMenu, c.busy.value), ('cancelled', false, null));
      expect(ok || c.job.value!.status == 'cancelled', isTrue);
      c.onClose();
    });

    test('deleting asks first', () async {
      when(() => jobs.delete(any())).thenAnswer((_) async => const ApiSuccess<void>(null));
      final c = office(jobOut(status: 'unassigned', assigneeId: null, actions: const ['assign', 'delete']));
      await c.load();
      c.confirmDelete = () async => false;
      await c.onDeleteTap();
      verifyNever(() => jobs.delete(any()));
      c.confirmDelete = () async => true;
      await _quietRun(c.onDeleteTap);
      verify(() => jobs.delete('j1')).called(1);
    });
  });

  group('Quick job and the Capture button', () {
    QuickJobController quick() => QuickJobController(
          jobs: jobs,
          dictation: fakeDictation(),
          clock: () => DateTime(2026, 11, 23, 10, 5),
        );

    Invocation? made;

    void stubCreate(ApiResult<JobOutModel> Function() answer) => when(
          () => jobs.create(
            title: any(named: 'title'),
            scheduledAt: any(named: 'scheduledAt'),
            clientUuid: any(named: 'clientUuid'),
            customerId: any(named: 'customerId'),
            newCustomer: any(named: 'newCustomer'),
            newCustomerPhone: any(named: 'newCustomerPhone'),
            address: any(named: 'address'),
            technicianId: any(named: 'technicianId'),
            checklistIds: any(named: 'checklistIds'),
          ),
        ).thenAnswer((i) async {
          made = i;
          return answer();
        });

    setUpAll(() {
      registerFallbackValue(DateTime(2026));
      registerFallbackValue(<String>[]);
    });

    test('needs the work and the customer, then makes the job and starts it', () async {
      stubCreate(() => ApiSuccess<JobOutModel>(jobOut(actions: const ['start'])));
      when(() => jobs.start(any(), lat: any(named: 'lat'), lng: any(named: 'lng')))
          .thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut(status: 'in_progress', actions: const [])));
      final c = quick();
      await c.onStartTap();
      expect(c.errors.keys.toSet(), {'work', 'customer'});
      c.work.text = ' Gas top-up ';
      c.customer.text = 'Raju Tea Stall';
      c.phone.text = '98250 22222';
      await _quietRun(c.onStartTap);
      final sent = made!.namedArguments;
      expect(
        [sent[#title], sent[#scheduledAt], sent[#newCustomer], sent[#newCustomerPhone], sent[#address]],
        ['Gas top-up', DateTime(2026, 11, 23, 10, 5), 'Raju Tea Stall', '98250 22222', null],
      );
      verify(() => jobs.start('j1')).called(1);
      expect(c.saving.value, isFalse);
    });

    test('a wrong phone shows under the phone; a failed start does not make the job twice', () async {
      stubCreate(() => const ApiFailure<JobOutModel>(ApiException(code: 'invalid_phone', message: 'x')));
      final c = quick()
        ..work.text = 'Gas top-up'
        ..customer.text = 'Raju';
      c.phone.text = '12';
      await c.onStartTap();
      expect(c.errors['phone'], "This phone number doesn't look right.");

      stubCreate(() => ApiSuccess<JobOutModel>(jobOut()));
      when(() => jobs.start(any(), lat: any(named: 'lat'), lng: any(named: 'lng')))
          .thenAnswer((_) async => const ApiFailure<JobOutModel>(ApiException(code: 'x', message: 'Try again.')));
      c.phone.clear();
      await _quietRun(c.onStartTap);
      await _quietRun(c.onStartTap);
      verify(() => jobs.start('j1')).called(2);
      verify(
        () => jobs.create(
          title: any(named: 'title'),
          scheduledAt: any(named: 'scheduledAt'),
          clientUuid: any(named: 'clientUuid'),
          newCustomer: any(named: 'newCustomer'),
          newCustomerPhone: any(named: 'newCustomerPhone'),
          address: any(named: 'address'),
        ),
      ).called(2); // the failed phone try and one real job: the second Start only starts it
    });

    test('Capture with no job going on offers today\'s next jobs', () {
      final j = jobOut();
      final shell = HomeShellController(session: session)
        ..nextJobs = () => [
              JobListItemModel(
                id: 'j2',
                number: j.number,
                title: j.title,
                status: 'assigned',
                scheduledAt: j.scheduledAt,
                customer: j.customer,
                isQuickJob: false,
                version: 1,
                updatedAt: j.updatedAt,
              ),
            ];
      final [next] = shell.captureJobs;
      final line = shell.jobLine(next); // the date library puts a narrow space before AM
      expect((line.startsWith('11:30'), line.endsWith(' · AC not cooling')), (true, true));
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

/// Toasts and going back need the app, which unit tests don't have.
Future<void> _quietRun(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}
