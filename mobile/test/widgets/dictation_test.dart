import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/UI/common_widgets/kn_dictation.dart';
import 'package:kaamnishaan/UI/theme/kn_app_theme.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/audio_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

/// Runs a call that shows a toast (toasts need the whole app, which a unit test doesn't have).
Future<void> _quiet(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

void main() {
  late FakeRecorder recorder;
  late MockFilesRepository files;
  late MockVoiceRepository voice;
  late Dictation d;

  setUpAll(() {
    registerFallbackValue(UploadKind.audio);
    registerFallbackValue(<int>[]);
  });

  setUp(() {
    recorder = FakeRecorder();
    files = MockFilesRepository();
    voice = MockVoiceRepository();
    d = Dictation(recorder: recorder, files: files, voice: voice, temp: () async => Directory.systemTemp);
    when(() => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')))
        .thenAnswer((_) async => const ApiSuccess<String>('a1'));
    when(() => voice.dictate(any(), languageHint: any(named: 'languageHint')))
        .thenAnswer((_) async => const ApiSuccess<DictationOutModel>(DictationOutModel(text: 'drain was blocked', language: 'en')));
  });

  test('the words are added to the box, and the recording is not kept', () async {
    final box = TextEditingController(text: 'Outdoor unit:');
    String? told;
    await d.toggle(box, language: 'hi', onText: (t) => told = t);
    expect((d.phaseOf(box), recorder.starts), (DictationPhase.listening, 1));
    final path = recorder.recording!;
    await d.toggle(box);
    expect(d.phaseOf(box), DictationPhase.idle);
    expect((box.text, told), ('Outdoor unit: drain was blocked', 'Outdoor unit: drain was blocked'));
    verify(() => files.upload(kind: UploadKind.audio, bytes: [1, 2, 3], contentType: 'audio/mp4')).called(1);
    verify(() => voice.dictate('a1', languageHint: 'hi')).called(1);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(File(path).existsSync(), isFalse);
  });

  test('nothing heard: the box stays as it was', () async {
    when(() => voice.dictate(any(), languageHint: any(named: 'languageHint')))
        .thenAnswer((_) async => const ApiFailure<DictationOutModel>(ApiException(code: 'unclear', message: 'x')));
    final box = TextEditingController(text: 'Gas low');
    await d.toggle(box);
    await _quiet(() => d.toggle(box));
    expect((d.phase.value, box.text), (DictationPhase.idle, 'Gas low'));
  });

  test('microphone off: nothing is recorded', () async {
    final off = FakeRecorder(result: MicResult.denied);
    final d2 = Dictation(recorder: off, files: files, voice: voice, temp: () async => Directory.systemTemp);
    await _quiet(() => d2.toggle(TextEditingController()));
    expect((d2.phase.value, off.starts), (DictationPhase.idle, 0));
  });

  test('tapping another box starts over there; each box shows only its own state', () async {
    final a = TextEditingController();
    final b = TextEditingController();
    await d.toggle(a);
    expect((d.phaseOf(a), d.phaseOf(b)), (DictationPhase.listening, DictationPhase.idle));
    await d.toggle(b);
    expect((d.phaseOf(a), d.phaseOf(b), recorder.starts), (DictationPhase.idle, DictationPhase.listening, 2));
    await d.toggle(b);
    expect((a.text, b.text), ('', 'drain was blocked'));
  });

  test('closing the box while the words are being written: they go nowhere', () async {
    final answer = Completer<ApiResult<DictationOutModel>>();
    when(() => voice.dictate(any(), languageHint: any(named: 'languageHint'))).thenAnswer((_) => answer.future);
    final box = TextEditingController();
    await d.toggle(box);
    final finishing = d.toggle(box);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(d.phase.value, DictationPhase.working);
    d.cancel();
    answer.complete(const ApiSuccess<DictationOutModel>(DictationOutModel(text: 'late words')));
    await finishing;
    expect((d.phase.value, box.text), (DictationPhase.idle, ''));
  });

  testWidgets('the button and the note follow the box they belong to', (tester) async {
    final a = TextEditingController();
    final b = TextEditingController();
    await tester.pumpWidget(
      GetMaterialApp(
        translations: KnTranslations(),
        locale: const Locale('en', 'IN'),
        theme: KnTheme.light(const Locale('en')),
        home: Scaffold(
          body: Column(
            children: [
              KnMicButton(key: const ValueKey('mic-a'), dictation: d, box: a),
              KnDictationNote(dictation: d, box: a),
              KnMicButton(key: const ValueKey('mic-b'), dictation: d, box: b),
              KnDictationNote(dictation: d, box: b),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('mic-a')));
    await tester.pump();
    expect(find.text('Listening… tap the square to stop'), findsOneWidget);
    d.cancel();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Listening… tap the square to stop'), findsNothing);
    Get.reset();
  });
}
