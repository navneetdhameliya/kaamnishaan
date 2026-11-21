import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_draft_section/report_draft_controller.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_editor_section/report_editor_controller.dart';
import 'package:kaamnishaan/UI/screens/report_section/report_making_section/report_making_controller.dart';
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

/// Toasts and navigation need the app, which unit tests don't have.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockReportsRepository reports;
  late TranslationService translation;
  const args = ReportArguments(
    jobId: 'j1',
    customer: 'Green Valley Clinic',
    reportId: 'r1',
    photos: 6,
    checklists: 2,
    notes: 2,
  );

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    reports = MockReportsRepository();
  });

  group('M31 making', () {
    ReportMakingController making() =>
        ReportMakingController(reports: reports, args: args, pollEvery: const Duration(hours: 1), autoStart: false);

    test('follows the server: photos and checklists read, then writing from the voice notes', () async {
      when(() => reports.start(any())).thenAnswer(
        (_) async => const ApiSuccess<ReportStartedModel>(ReportStartedModel(reportId: 'r1', taskId: 't1', status: 'generating')),
      );
      when(() => reports.task(any())).thenAnswer((_) async => ApiSuccess<TaskOutModel>(taskOut('running', ['done', 'running', 'waiting'])));
      final c = making();
      await c.start();
      await c.check();
      expect(c.rows.map((r) => r.text), [
        'Reading 6 photos',
        'Checking 2 checklists',
        'Writing from 2 voice notes',
        'Looking for missing proof',
      ]);
      expect(c.rows.map((r) => r.state), [RowState.done, RowState.done, RowState.running, RowState.waiting]);
      expect(c.progress, closeTo(0.5, 0.001));
      expect(c.phase.value, MakePhase.working);
      c.onClose();
    });

    test('when writing fails the proof is safe and it can be tried again', () async {
      when(() => reports.start(any())).thenAnswer(
        (_) async => const ApiSuccess<ReportStartedModel>(ReportStartedModel(reportId: 'r1', taskId: 't1', status: 'generating')),
      );
      when(() => reports.task(any())).thenAnswer((_) async => ApiSuccess<TaskOutModel>(taskOut('failed', ['done', 'failed', 'waiting'])));
      final c = making();
      await c.start();
      await c.check();
      expect(c.phase.value, MakePhase.failed);
      await c.start();
      expect(c.phase.value, MakePhase.working);
      verify(() => reports.start('j1')).called(2);
      c.onClose();
    });

    test('a missing connection while waiting just asks again', () async {
      when(() => reports.start(any())).thenAnswer(
        (_) async => const ApiSuccess<ReportStartedModel>(ReportStartedModel(reportId: 'r1', taskId: 't1', status: 'generating')),
      );
      when(() => reports.task(any()))
          .thenAnswer((_) async => const ApiFailure<TaskOutModel>(ApiException(code: 'no_internet', message: '')));
      final c = making();
      await c.start();
      await c.check();
      expect(c.phase.value, MakePhase.working);
      c.onClose();
    });
  });

  group('M31 draft', () {
    late MockJobsRepository jobs;

    ReportDraftController draft(ReportOutModel r) {
      jobs = MockJobsRepository();
      when(() => reports.report(any())).thenAnswer((_) async => ApiSuccess<ReportOutModel>(r));
      when(() => jobs.evidence(any())).thenAnswer(
        (_) async => const ApiSuccess<EvidenceListModel>(EvidenceListModel(data: [], meta: ListMetaModel(), pairs: [])),
      );
      final session = SessionService(tokens: MemoryTokenStorage(), repository: MockAuthRepository());
      return ReportDraftController(
        reports: reports,
        jobs: jobs,
        session: session,
        speech: FakeSpeech(),
        translation: translation,
        args: args,
      );
    }

    test('says what the AI used and what proof is missing', () async {
      final c = draft(
        reportOut(flags: const [
          ReportFlagModel(kind: 'missing_evidence', text: 'after photo of outdoor unit'),
          ReportFlagModel(kind: 'unsupported_claim', text: 'Checked the gas pressure.'),
        ]),
      );
      await c.load();
      expect(c.proofText, 'Drafted by AI from 6 photos, 12 answers and 2 voice notes. Check before sending.');
      expect(c.missing.map((f) => f.text), ['after photo of outdoor unit']);
      expect(c.subtitle, 'Green Valley Clinic · #R-1042');
      expect(c.byLine, 'Ramesh Patel · 31 Oct 2026');
      expect((c.canEdit, c.canSend, c.stateText), (true, true, null));
    });

    test('"Send to manager" sends it; afterwards it is read-only and waiting', () async {
      final c = draft(reportOut());
      await c.load();
      when(() => reports.submit(any())).thenAnswer(
        (_) async => ApiSuccess<ReportOutModel>(reportOut(status: 'pending_review', actions: const [])),
      );
      await _ignoreApp(c.onSendTap);
      verify(() => reports.submit('r1')).called(1);
      expect(c.canEdit, isFalse);
      expect(c.missing, isEmpty);
      expect(c.stateText, 'Waiting for manager');
    });
  });

  group('M32 editor', () {
    Future<ReportEditorController> editor() async {
      when(() => reports.report(any())).thenAnswer((_) async => ApiSuccess<ReportOutModel>(reportOut()));
      final c = ReportEditorController(reports: reports, speech: FakeSpeech(), translation: translation, dictation: fakeDictation(), args: args)
        ..onInit();
      await c.load();
      return c;
    }

    test('nothing to save until something changes; an empty "Work done" blocks saving', () async {
      final c = await editor();
      expect(c.canSave, isFalse);
      final work = c.parts[1];
      work.text.text = '';
      expect(work.empty.value, isTrue);
      expect(c.canSave, isFalse);
      expect(c.emptyText(work), "Work done can't be empty. Speak or type.");
      work.text.text = 'Cleaned the filter.';
      expect(work.empty.value, isFalse);
      expect(c.canSave, isTrue);
      c.onClose();
    });

    test('only the changed parts are sent', () async {
      final c = await editor();
      when(() => reports.edit(any(), summary: any(named: 'summary'), workDone: any(named: 'workDone'), advice: any(named: 'advice')))
          .thenAnswer((_) async => ApiSuccess<ReportOutModel>(reportOut(summary: 'Serviced the AC.')));
      c.parts.first.text.text = 'Serviced the AC.';
      await _ignoreApp(c.onSaveTap);
      verify(() => reports.edit('r1', summary: 'Serviced the AC.', workDone: null, advice: null)).called(1);
      c.onClose();
    });

    test('AI writes one part again and keeps the others', () async {
      when(() => reports.report(any())).thenAnswer((_) async => ApiSuccess<ReportOutModel>(reportOut()));
      when(() => reports.regenerate(any(), any())).thenAnswer(
        (_) async => const ApiSuccess<ReportStartedModel>(ReportStartedModel(reportId: 'r1', taskId: 't2', status: 'draft')),
      );
      when(() => reports.task(any())).thenAnswer((_) async => ApiSuccess<TaskOutModel>(taskOut('done', ['done', 'done', 'done'])));
      final c = ReportEditorController(dictation: fakeDictation(), 
        reports: reports,
        speech: FakeSpeech(),
        translation: translation,
        args: args,
        pollEvery: Duration.zero,
      )..onInit();
      await c.load();
      c.parts.first.text.text = 'My own summary';
      when(() => reports.report(any()))
          .thenAnswer((_) async => ApiSuccess<ReportOutModel>(reportOut(advice: 'Book a service in 6 months.')));
      await _ignoreApp(() => c.rewrite(c.parts[2]));
      verify(() => reports.regenerate('r1', 'advice')).called(1);
      expect(c.parts[2].text.text, 'Book a service in 6 months.');
      expect(c.parts.first.text.text, 'My own summary');
      c.onClose();
    });
  });
}
