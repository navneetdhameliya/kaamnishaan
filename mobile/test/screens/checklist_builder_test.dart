import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/UI/screens/checklists_section/checklist_builder_section/checklist_builder_controller.dart';
import 'package:kaamnishaan/UI/screens/checklists_section/checklist_builder_section/custom_widgets/question_sheet.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/job_list_section/custom_widgets/job_list_parts.dart';
import 'package:kaamnishaan/UI/theme/kn_app_theme.dart';
import 'package:kaamnishaan/UI/screens/checklists_section/checklist_library_section/checklist_library_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/audio_service.dart';
import 'package:kaamnishaan/infrastructure/services/image_picker_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

/// Runs a call that shows a toast (toasts need the whole app, which a unit test doesn't have).
Future<T?> _quiet<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on Object catch (_) {
    return null;
  }
}

Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

const ready = {'en': 'ready', 'hi': 'ready', 'gu': 'ready', 'es': 'ready', 'fr': 'ready'};

TemplateQuestionOutModel question(
  String id,
  int position,
  String type,
  String text, {
  String photo = 'none',
  String? ref,
  List<OptionOutModel> options = const [],
  Map<String, dynamic>? condition,
  bool required = true,
}) =>
    TemplateQuestionOutModel(
      id: id,
      position: position,
      type: type,
      text: text,
      textAll: {'en': text},
      textStatus: position == 3 ? {...ready, 'gu': 'needs_review'} : ready,
      options: options,
      photoRule: photo,
      requiredValue: required,
      referenceImageUrl: ref,
      condition: condition,
    );

TemplateOutModel template({String scope = 'company', String status = 'draft', List<TemplateQuestionOutModel>? qs}) {
  final questions = qs ??
      [
        question('q1', 1, 'yes_no', 'Is the air filter clean?'),
        question('q2', 2, 'number', 'Refrigerant pressure'),
        question('q3', 3, 'pass_fail', 'Drain pipe condition', photo: 'if_fail'),
      ];
  return TemplateOutModel(
    id: 't1',
    name: 'HVAC service check',
    scope: scope,
    status: status,
    version: 1,
    questionCount: questions.length,
    usageCount: 21,
    needsTranslation: 0,
    language: 'en',
    questions: questions,
    editable: scope == 'company',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockChecklistsRepository checklists;
  late MockFilesRepository files;
  late FakeImagePicker picker;
  late FakeRecorder recorder;
  late MockVoiceRepository voice;
  Future<Directory> temp() async => Directory.systemTemp;

  setUpAll(() {
    registerFallbackValue(const QuestionInModel(type: 'yes_no', text: ''));
    registerFallbackValue(const QuestionPatchModel());
    registerFallbackValue(UploadKind.photo);
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    checklists = MockChecklistsRepository();
    files = MockFilesRepository();
    picker = FakeImagePicker();
    recorder = FakeRecorder();
    voice = MockVoiceRepository();
  });

  test('M26 shows the questions, their types and the languages ready', () async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    expect((c.name, c.subtitle), ('HVAC service check', '3 questions · used in 21 jobs'));
    expect(c.translations, 'Translations: 4 of 5 languages ready');
    expect([for (final q in c.questions) c.chip(q)], ['Yes / No', 'Number', 'Pass / Fail · photo']);
    expect((c.editable, c.draft), (true, true));
  });

  test('M26 add a Pass / Fail question with a photo when it fails', () async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    when(() => checklists.addQuestion(any(), any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    c.startAdd();
    c.text.text = 'Is the condensate drain clear?';
    c.onType('pass_fail');
    expect(c.photoLabel, 'Photo needed if Fail');
    c.photo.value = true;
    expect(await c.onSaveQuestion(), isTrue);
    final sent = verify(() => checklists.addQuestion('t1', captureAny())).captured.single as QuestionInModel;
    expect((sent.type, sent.text, sent.photoRule, sent.unit), ('pass_fail', 'Is the condensate drain clear?', 'if_fail', null));
  });

  test('M26 edit keeps the type; numbers can have a unit', () async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    when(() => checklists.updateQuestion(any(), any(), any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    c.startEdit(c.questions[1]);
    c.onType('yes_no');
    expect(c.type.value, 'number'); // locked
    c.unit.text = 'psi';
    c.photo.value = true;
    await c.onSaveQuestion();
    final sent = verify(() => checklists.updateQuestion('t1', 'q2', captureAny())).captured.single as QuestionPatchModel;
    expect((sent.text, sent.unit, sent.photoRule), ('Refrigerant pressure', 'psi', 'always'));
  });

  test('M26 a reference photo is uploaded with the question, and can be taken off', () async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    when(() => checklists.addQuestion(any(), any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    when(() => checklists.updateQuestion(any(), any(), any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    when(() => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')))
        .thenAnswer((_) async => const ApiSuccess<String>('up1'));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();

    // add: pick a photo, it goes up with the question
    c.startAdd();
    c.text.text = 'Is the outdoor unit level?';
    expect(c.hasReference, isFalse);
    picker.next = tinyJpeg;
    await c.onPickReference(PickSource.camera);
    expect(c.hasReference, isTrue);
    expect(picker.sources, [PickSource.camera]);
    expect(await c.onSaveQuestion(), isTrue);
    verify(() => files.upload(kind: UploadKind.photo, bytes: tinyJpeg.bytes, contentType: 'image/jpeg')).called(1);
    final added = verify(() => checklists.addQuestion('t1', captureAny())).captured.single as QuestionInModel;
    expect(added.referenceUploadId, 'up1');

    clearInteractions(checklists);
    // edit: the saved photo shows; removing it sends remove_reference
    c.startEdit(question('q1', 1, 'yes_no', 'Is the air filter clean?', ref: 'https://x/ref.jpg'));
    expect((c.hasReference, c.referenceUrl.value), (true, 'https://x/ref.jpg'));
    c.onRemoveReference();
    await c.onSaveQuestion();
    final removed = verify(() => checklists.updateQuestion('t1', 'q1', captureAny())).captured.single as QuestionPatchModel;
    expect((removed.removeReference, removed.referenceUploadId), (true, null));

    clearInteractions(checklists);
    // edit without touching the photo sends neither
    c.startEdit(question('q1', 1, 'yes_no', 'Is the air filter clean?', ref: 'https://x/ref.jpg'));
    await c.onSaveQuestion();
    final kept = verify(() => checklists.updateQuestion('t1', 'q1', captureAny())).captured.single as QuestionPatchModel;
    expect((kept.removeReference, kept.referenceUploadId), (null, null));
  });

  test('M26 a choice question, optional, shown only after an earlier answer', () async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    when(() => checklists.addQuestion(any(), any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    c.startAdd();
    c.text.text = 'Filter state';
    c.onType('choice');
    expect(c.options.length, 2); // two empty boxes to start
    c.options[0].text.text = 'Clean';
    await _quiet(c.onSaveQuestion); // needs 2 choices: a note, nothing sent
    verifyNever(() => checklists.addQuestion(any(), any()));
    c.options[1].text.text = 'Dusty';
    c.onAddOption();
    c.options[2].text.text = ' Torn ';
    c.requiredAnswer.value = false;
    // only Yes/No, Pass/Fail and choice questions can be waited for
    expect([for (final q in c.ruleSources) q.id], ['q1', 'q3']);
    c.onRuleQuestion('q3');
    expect(c.ruleEquals.value, 'pass'); // the first answer to start with
    c.onRuleAnswer('fail');
    expect(await c.onSaveQuestion(), isTrue);
    final sent = verify(() => checklists.addQuestion('t1', captureAny())).captured.single as QuestionInModel;
    expect([for (final o in sent.options!) o.label], ['Clean', 'Dusty', 'Torn']);
    expect((sent.type, sent.requiredValue, sent.condition?.questionId, sent.condition?.equals), ('choice', false, 'q3', 'fail'));
  });

  test('M26 editing keeps choice keys, can drop the rule, and only earlier questions are offered', () async {
    final qs = [
      question('q1', 1, 'yes_no', 'Ducts dusty?'),
      question('q2', 2, 'choice', 'Filter state', options: const [
        OptionOutModel(key: 'clean', label: 'Clean'),
        OptionOutModel(key: 'torn', label: 'Torn'),
      ]),
      question('q3', 3, 'photo', 'Photo of the tear', condition: {'question_id': 'q2', 'equals': 'torn'}, required: false),
    ];
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template(qs: qs)));
    when(() => checklists.updateQuestion(any(), any(), any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template(qs: qs)));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    expect(c.note(qs[2]), 'Only if Q2 is Torn · Optional');
    expect(c.note(qs[0]), isNull);

    c.startEdit(qs[1]);
    expect([for (final q in c.ruleSources) q.id], ['q1']);
    c.options[1].text.text = 'Ripped';
    await c.onSaveQuestion();
    final opts = (verify(() => checklists.updateQuestion('t1', 'q2', captureAny())).captured.single as QuestionPatchModel).options!;
    expect([for (final o in opts) (o.key, o.label)], [('clean', 'Clean'), ('torn', 'Ripped')]);

    c.startEdit(qs[2]);
    expect((c.ruleQuestionId.value, c.ruleEquals.value, c.requiredAnswer.value), ('q2', 'torn', false));
    c.onRuleQuestion(null);
    await c.onSaveQuestion();
    final patch = verify(() => checklists.updateQuestion('t1', 'q3', captureAny())).captured.single as QuestionPatchModel;
    expect((patch.condition, patch.clearCondition, patch.options), (null, true, null));
  });

  test('M26 preview shows a waiting question only after its answer', () async {
    final qs = [
      question('q1', 1, 'pass_fail', 'Drain clear?'),
      question('q2', 2, 'photo', 'Photo of the block', condition: {'question_id': 'q1', 'equals': 'fail'}),
      question('q3', 3, 'yes_no', 'Cleaned it?', condition: {'question_id': 'q2', 'equals': 'yes'}),
      question('q4', 4, 'number', 'Pressure'),
    ];
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template(qs: qs)));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    c.startPreview();
    expect([for (final q in c.previewQuestions) q.id], ['q1', 'q4']);
    expect(c.previewCount, '2 of 4 questions shown · tap answers to try the rules');
    c.onPreviewAnswer(qs[0], 'fail');
    expect([for (final q in c.previewQuestions) q.id], ['q1', 'q2', 'q4']);
    c.onPreviewAnswer(qs[0], 'fail'); // tapping again clears it
    expect([for (final q in c.previewQuestions) q.id], ['q1', 'q4']);
  });

  test('M26 translations open on the language that needs a look; saving makes it ready', () async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    when(() => checklists.updateQuestion(any(), any(), any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    expect(c.otherLanguages, ['hi', 'gu', 'es', 'fr']);
    expect((c.toCheck('hi'), c.toCheck('gu')), (0, 1)); // q3 was translated automatically into Gujarati
    c.startTranslations();
    expect(c.trLanguage.value, 'gu');
    expect(c.trBoxes.keys.toList(), ['q1', 'q2', 'q3']);

    c.trBoxes['q3']!.text = '  ડ્રેન પાઇપની સ્થિતિ ';
    await _quiet(() => c.onSaveTranslation(c.questions[2]));
    final patch = verify(() => checklists.updateQuestion('t1', 'q3', captureAny())).captured.single as QuestionPatchModel;
    expect(patch.translations, {'gu': 'ડ્રેન પાઇપની સ્થિતિ'});
    expect(c.trSaving.value, isNull);

    // an empty box is not sent
    c.trBoxes['q1']!.text = ' ';
    await _quiet(() => c.onSaveTranslation(c.questions[0]));
    verifyNever(() => checklists.updateQuestion('t1', 'q1', any()));

    c.onTrLanguage('fr');
    expect(c.trLanguage.value, 'fr');
  });

  test('M26 speak instead of typing: the words go into the question box', () async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    when(() => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')))
        .thenAnswer((_) async => const ApiSuccess<String>('a1'));
    when(() => voice.dictate(any(), languageHint: any(named: 'languageHint')))
        .thenAnswer((_) async => const ApiSuccess<DictationOutModel>(DictationOutModel(text: 'is the drain clear?', language: 'en')));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    c.startAdd();
    c.text.text = 'Outdoor unit:';

    await c.onMicTap();
    expect((c.dictation.value, recorder.starts), (DictationPhase.listening, 1));
    final path = recorder.recording!;
    await c.onMicTap();
    expect(c.dictation.value, DictationPhase.idle);
    expect(c.text.text, 'Outdoor unit: is the drain clear?');
    verify(() => files.upload(kind: UploadKind.audio, bytes: [1, 2, 3], contentType: 'audio/mp4')).called(1);
    verify(() => voice.dictate('a1', languageHint: 'en')).called(1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(File(path).existsSync(), isFalse); // the recording isn't kept on the phone

    // nothing heard: the box stays as it was
    when(() => voice.dictate(any(), languageHint: any(named: 'languageHint')))
        .thenAnswer((_) async => const ApiFailure<DictationOutModel>(ApiException(code: 'unclear', message: "Couldn't hear any words.")));
    await c.onMicTap();
    await _quiet(c.onMicTap);
    expect((c.dictation.value, c.text.text), (DictationPhase.idle, 'Outdoor unit: is the drain clear?'));

    // closing or reopening the sheet while listening drops the recording
    await c.onMicTap();
    c.startAdd();
    expect((c.dictation.value, recorder.recording), (DictationPhase.idle, null));
  });

  test('M26 microphone off: nothing is recorded', () async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    final off = FakeRecorder(result: MicResult.denied);
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: off, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    await _quiet(c.onMicTap);
    expect((c.dictation.value, off.starts), (DictationPhase.idle, 0));
  });

  testWidgets('M26 question sheet parts redraw as they change', (tester) async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    c.startAdd();
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    await tester.pumpWidget(
      GetMaterialApp(
        translations: KnTranslations(),
        locale: const Locale('en', 'IN'),
        theme: KnTheme.light(const Locale('en')),
        home: Scaffold(body: QuestionSheet(controller: c)),
      ),
    );
    await tester.pump();
    bool selected(String key) => tester.widget<JobFilterChip>(find.byKey(ValueKey(key))).selected;
    expect(selected('question-rule-always'), isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('question-rule-q3')));
    await tester.tap(find.byKey(const ValueKey('question-rule-q3')));
    await tester.pump();
    expect((selected('question-rule-always'), selected('question-rule-q3')), (false, true));
    await tester.ensureVisible(find.byKey(const ValueKey('question-rule-answer-fail')));
    await tester.tap(find.byKey(const ValueKey('question-rule-answer-fail')));
    await tester.pump();
    expect(selected('question-rule-answer-fail'), isTrue);

    await tester.ensureVisible(find.byKey(const ValueKey('question-mic')));
    await tester.tap(find.byKey(const ValueKey('question-mic')));
    await tester.pump();
    expect(find.text('Listening… tap the square to stop'), findsOneWidget);
    c.startAdd(); // stops listening
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('question-mic-state')), findsNothing);
    await tester.binding.setSurfaceSize(null);
    Get.reset();
  });

  test('M26 drag to move saves the new place', () async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    when(() => checklists.updateQuestion(any(), any(), any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 't1');
    await c.load();
    final moving = c.onReorder(2, 0);
    expect([for (final q in c.questions) q.id], ['q3', 'q1', 'q2']); // shown at once
    await moving;
    final sent = verify(() => checklists.updateQuestion('t1', 'q3', captureAny())).captured.single as QuestionPatchModel;
    expect(sent.position, 1);
  });

  test('M26 save publishes; a KaamNishaan checklist is copied first', () async {
    when(() => checklists.template(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template(scope: 'global')));
    when(() => checklists.copy(any())).thenAnswer((_) async => ApiSuccess<TemplateOutModel>(template()));
    when(() => checklists.update(any(), status: any(named: 'status'), name: any(named: 'name'))).thenAnswer(
      (_) async => ApiSuccess<TemplateOutModel>(template(status: 'published')),
    );
    final c = ChecklistBuilderController(checklists: checklists, files: files, picker: picker, recorder: recorder, voice: voice, temp: temp, templateId: 'g1');
    await c.load();
    expect(c.editable, isFalse);
    await _ignoreApp(c.onCopy);
    expect((c.editable, c.templateId.value), (true, 't1'));
    await _ignoreApp(c.onSave);
    verify(() => checklists.update('t1', status: 'published')).called(1);
    expect(c.draft, isFalse);
  });

  test('Checklists: the company’s own first, with a badge for drafts and KaamNishaan’s', () async {
    when(() => checklists.templates()).thenAnswer(
      (_) async => const ApiSuccess<TemplateListModel>(
        TemplateListModel(
          data: [
            TemplateListItemModel(id: 'g1', name: 'AC service', scope: 'global', status: 'published', version: 1, questionCount: 12, usageCount: 0, needsTranslation: 0),
            TemplateListItemModel(id: 't1', name: 'Our check', scope: 'company', status: 'draft', version: 1, questionCount: 3, usageCount: 2, needsTranslation: 0),
          ],
          meta: ListMetaModel(),
        ),
      ),
    );
    final c = ChecklistLibraryController(checklists: checklists);
    await c.load();
    expect([for (final t in c.items) t.id], ['t1', 'g1']);
    expect([for (final t in c.items) c.badge(t)], ['Draft', 'By KaamNishaan']);
    expect(c.meta(c.items.first), '3 questions · used in 2 jobs');
  });
}
