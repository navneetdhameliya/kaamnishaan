import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/checklists_section/checklist_question_section/checklist_question_controller.dart';
import 'package:kaamnishaan/UI/screens/checklists_section/checklists_section/checklists_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_details_section/photo_details_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_pair_section/photo_pair_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/photo_queue_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/shared/job_arguments.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

EvidenceOutModel ev(String id, String stage, int minute, {String? slot}) => EvidenceOutModel(
      id: id,
      jobId: 'j1',
      stage: stage,
      shotSlot: slot,
      url: 'https://x/$id.jpg',
      size: 1,
      processing: 'ready',
      takenAt: DateTime(2026, 10, 31, 10, minute),
      takenBy: const PersonRefModel(id: 'u1', name: 'Ramesh Patel'),
      locked: false,
      notesCount: 0,
    );

/// Toasts need the app overlay, which unit tests don't have.
Future<void> _ignoreToast(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late MockChecklistsRepository checklists;
  late MockFilesRepository files;
  late MockJobsRepository jobs;
  late PhotoQueueService queue;
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
    tmp = Directory.systemTemp.createTempSync('kn_chk_');
    checklists = MockChecklistsRepository();
    files = MockFilesRepository();
    jobs = MockJobsRepository();
    // no internet: answers stay on the phone
    when(
      () => checklists.answer(
        checklistId: any(named: 'checklistId'),
        questionId: any(named: 'questionId'),
        clientUuid: any(named: 'clientUuid'),
        value: any(named: 'value'),
        photoId: any(named: 'photoId'),
        signatureUploadId: any(named: 'signatureUploadId'),
      ),
    ).thenAnswer((_) async => const ApiFailure<SubmissionOutModel>(ApiException(code: 'no_internet', message: '')));
    when(
      () => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')),
    ).thenAnswer((_) async => const ApiFailure<String>(ApiException(code: 'no_internet', message: '')));
    queue = await PhotoQueueService(
      files: files,
      jobs: jobs,
      checklists: checklists,
      folder: () async => Directory('${tmp.path}/pending'),
      retryEvery: const Duration(hours: 1),
    ).init();
  });

  tearDown(() {
    queue.onClose();
    tmp.deleteSync(recursive: true);
  });

  group('M25 question', () {
    // q1 yes/no (photo if no); q2 only when q1 = no; q3 number
    List<QuestionOutModel> questions({Object? a1}) => [
          question('q1', 1, photoRule: 'if_no', answer: a1),
          question('q2', 2, type: 'text', text: 'What was wrong?', condition: {'question_id': 'q1', 'equals': 'no'}, visible: false),
          question('q3', 3, type: 'number', text: 'Gas pressure?'),
        ];

    ChecklistQuestionController open(List<QuestionOutModel> qs) {
      when(() => checklists.submission(any())).thenAnswer(
        (_) async => ApiSuccess<SubmissionOutModel>(
          SubmissionOutModel(
            id: 'c1', jobId: 'j1', name: 'HVAC service check', language: 'en', answered: 0, total: qs.length,
            status: 'in_progress', locked: false, questions: qs,
          ),
        ),
      );
      return ChecklistQuestionController(
        checklists: checklists,
        files: files,
        queue: queue,
        speech: FakeSpeech(),
        translation: translation,
        args: const ChecklistArguments(jobId: 'j1', checklistId: 'c1', customer: 'Green Valley Clinic'),
        advanceDelay: Duration.zero,
      );
    }

    test('starts at the first unanswered question; "Yes" is kept on the phone and moves on', () async {
      final c = open(questions());
      await c.load();
      expect(c.current?.id, 'q1');
      expect(c.shown.map((q) => q.id), ['q1', 'q3']); // q2 hidden until q1 = no
      expect((c.position, c.shown.length), (1, 2));
      await c.onChoose('yes');
      expect(queue.answersFor('c1')['q1']?.value, 'yes');
      expect(c.current?.id, 'q3');
      expect(c.percent, 50);
      c.onClose();
    });

    test('"No" asks for a photo first; the photo then carries the answer; the follow-up question appears', () async {
      final c = open(questions());
      await c.load();
      await c.onChoose('no');
      expect(c.photoNeeded.value, isTrue);
      expect(queue.answers, isEmpty); // nothing sent without the photo
      expect(c.current?.id, 'q1');
      expect(c.shown.map((q) => q.id), ['q1', 'q2', 'q3']); // "show if no" follows the answer on the phone
      // the photo comes back from the camera (simulated)
      final photo = await queue.add(jobId: 'j1', stage: 'during', sourcePath: (File('${tmp.path}/p.jpg')..writeAsBytesSync([1])).path);
      await queue.addAnswer(jobId: 'j1', checklistId: 'c1', questionId: 'q1', value: 'no', photoRef: photo.id);
      c.drafts.remove('q1');
      expect(c.hasPhoto(c.current!), isTrue);
      expect(c.isComplete(c.current!), isTrue);
      c.onClose();
    });

    test('numbers are checked against the allowed range', () async {
      final c = open([
        question('q1', 1, answer: 'yes'),
        const QuestionOutModel(
          id: 'q3', position: 2, type: 'number', text: 'Gas pressure?', translationStatus: 'ready', options: [],
          photoRule: 'none', requiredValue: true, visible: true, photoNeeded: false, minValue: 50, maxValue: 150, unit: 'psi',
        ),
        question('q4', 3),
      ]);
      await c.load();
      expect(c.current?.id, 'q3'); // q1 already answered on the server
      c.textController.text = '400';
      await _ignoreToast(c.onSubmitTyped); // the "50 to 150" message needs the app's toast overlay
      expect(c.current?.id, 'q3');
      expect(queue.answers, isEmpty);
      c.textController.text = '118';
      await c.onSubmitTyped();
      expect(queue.answersFor('c1')['q3']?.value, 118.0);
      expect(c.current?.id, 'q4');
      c.onClose();
    });
  });

  test('M24 list: answers waiting on the phone count; the first unfinished list is the one to do', () async {
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
    final c = ChecklistsController(
      checklists: checklists,
      queue: queue,
      translation: translation,
      args: const ChecklistArguments(jobId: 'j1', customer: 'Green Valley Clinic'),
    );
    await c.load();
    expect(c.active?.id, 'c1');
    expect(c.startLabel, 'Start HVAC service check');
    expect(c.meta(c.active!), '12 questions · about 5 min');
    expect(c.doneLine(c.lists.first), startsWith('6 of 6 · done at 10:45'));
    await queue.addAnswer(jobId: 'j1', checklistId: 'c1', questionId: 'q1', value: 'yes');
    expect(c.answeredOf(c.active!), 1);
    expect(c.startLabel, 'Continue HVAC service check');
    c.onClose();
  });

  test('M22 pairs the same checklist shot before and after', () async {
    when(() => jobs.evidence(any())).thenAnswer(
      (_) async => ApiSuccess<EvidenceListModel>(
        EvidenceListModel(
          data: [ev('b1', 'before', 50, slot: 'filter'), ev('b2', 'before', 55), ev('a1', 'after', 58, slot: 'filter'), ev('a2', 'after', 59)],
          meta: const ListMetaModel(),
          pairs: const [],
        ),
      ),
    );
    when(() => jobs.addPair(jobId: any(named: 'jobId'), beforeId: any(named: 'beforeId'), afterId: any(named: 'afterId'), subject: any(named: 'subject')))
        .thenAnswer((_) async => ApiSuccess<PairOutModel>(PairOutModel(id: 'p1', before: ev('b1', 'before', 50), after: ev('a1', 'after', 58), useInReport: true)));
    final c = PhotoPairController(
      jobs: jobs,
      translation: translation,
      args: const PhotoDetailArguments(jobId: 'j1', customer: 'Green Valley Clinic', place: 'Room 2 · AC unit'),
    );
    await c.load();
    expect((c.before.value?.id, c.after.value?.id), ('b1', 'a1'));
    c.onDrag(2);
    expect(c.split.value, 0.95);
    await _ignoreToast(c.onUseTap); // "Added to the report" toast, then back
    verify(() => jobs.addPair(jobId: 'j1', beforeId: 'b1', afterId: 'a1', subject: 'Room 2 · AC unit')).called(1);
    expect(c.pairId.value, 'p1');
  });

  test('M23 shows the stage, time and the latest note', () async {
    when(() => jobs.photo(any())).thenAnswer(
      (_) async => ApiSuccess<EvidenceDetailModel>(
        EvidenceDetailModel(
          id: 'b1', jobId: 'j1', stage: 'before', url: 'https://x/b1.jpg', size: 1, processing: 'ready',
          takenAt: DateTime(2026, 10, 31, 10, 52), takenBy: const PersonRefModel(id: 'u1', name: 'Ramesh Patel'),
          locked: true, notesCount: 1, canDelete: false,
          notes: [NoteOutModel(id: 'n1', author: const PersonRefModel(id: 'u1', name: 'Ramesh'), text: 'Filter blocked with dust.', createdAt: DateTime(2026, 10, 31, 10, 53))],
        ),
      ),
    );
    final c = PhotoDetailsController(
      jobs: jobs,
      translation: translation,
      args: const PhotoDetailArguments(jobId: 'j1', evidenceId: 'b1', index: 1, total: 3),
    );
    await c.load();
    expect(c.chip, 'BEFORE · photo 1 of 3');
    expect(c.taken, startsWith('31 Oct 2026 · 10:52'));
    expect(c.latestNote, 'Filter blocked with dust.');
    expect(c.canDelete, isFalse);
    c.onClose();
  });
}
