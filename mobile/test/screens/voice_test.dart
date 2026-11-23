import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/UI/screens/voice_section/voice_note_section/voice_note_controller.dart';
import 'package:kaamnishaan/UI/screens/voice_section/voice_notes_section/voice_notes_controller.dart';
import 'package:kaamnishaan/UI/screens/voice_section/voice_record_section/voice_record_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/audio_service.dart';
import 'package:kaamnishaan/infrastructure/services/photo_queue_service.dart';
import 'package:kaamnishaan/infrastructure/shared/job_arguments.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

/// Toasts and Get.back need the app, which unit tests don't have.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late MockFilesRepository files;
  late MockVoiceRepository voice;
  late PhotoQueueService queue;
  const args = VoiceArguments(jobId: 'j1', customer: 'Green Valley Clinic');

  setUpAll(() {
    registerFallbackValue(UploadKind.audio);
    registerFallbackValue(<int>[]);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    tmp = Directory.systemTemp.createTempSync('kn_voice_');
    files = MockFilesRepository();
    voice = MockVoiceRepository();
    // no internet: notes stay on the phone
    when(() => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')))
        .thenAnswer((_) async => const ApiFailure<String>(ApiException(code: 'no_internet', message: '')));
    when(() => voice.addTyped(jobId: any(named: 'jobId'), text: any(named: 'text'), clientUuid: any(named: 'clientUuid')))
        .thenAnswer((_) async => const ApiFailure<VoiceNoteOutModel>(ApiException(code: 'no_internet', message: '')));
    queue = await PhotoQueueService(
      files: files,
      jobs: MockJobsRepository(),
      voice: voice,
      folder: () async => Directory('${tmp.path}/pending'),
      retryEvery: const Duration(hours: 1),
    ).init();
  });

  tearDown(() async {
    await queue.process(); // a send started by the test may still be reading a file in the folder
    queue.onClose();
    tmp.deleteSync(recursive: true);
  });

  group('M27 recorder', () {
    VoiceRecordController recorder(FakeRecorder mic) => VoiceRecordController(
          recorder: mic,
          queue: queue,
          args: args,
          temp: () async => tmp,
          openSettings: () async => true,
          autoStart: false,
        );

    test('microphone off shows the "turn it on" screen; a typed note is kept instead', () async {
      final c = recorder(FakeRecorder(result: MicResult.denied));
      await c.begin();
      expect(c.phase.value, RecordPhase.denied);
      c.typedController.text = '  Cleaned the filter  ';
      await _ignoreApp(() async {
        await c.onSaveTypedTap();
      });
      expect(queue.notesFor('j1').single.text, 'Cleaned the filter');
      expect(queue.notesFor('j1').single.typed, isTrue);
      c.onClose();
    });

    test('record, pause, go on, then stop and save keeps the note with its length and language', () async {
      final mic = FakeRecorder();
      final c = recorder(mic);
      await c.begin();
      expect(c.phase.value, RecordPhase.recording);
      mic.levelsController.add(0.7);
      await Future<void>.delayed(Duration.zero);
      expect(c.levels.last, 0.7);
      await c.onPauseTap();
      expect((c.phase.value, mic.paused), (RecordPhase.paused, true));
      expect(c.statusText, startsWith('Paused'));
      await c.onPauseTap();
      expect(c.phase.value, RecordPhase.recording);
      c.onLanguageTap('gu');
      c.elapsed.value = const Duration(seconds: 42);
      await _ignoreApp(c.onStopSaveTap);
      final note = queue.notesFor('j1').single;
      expect(note.durationS, 42);
      expect(note.languageHint, 'gu');
      expect(File(note.path!).existsSync(), isTrue); // moved into the app's folder
      c.onClose();
    });

    test('a too short recording is not kept and recording starts again', () async {
      final mic = FakeRecorder();
      final c = recorder(mic);
      await c.begin();
      c.elapsed.value = const Duration(milliseconds: 400);
      await _ignoreApp(c.onStopSaveTap);
      expect(queue.notes, isEmpty);
      expect(mic.starts, 2);
      expect(c.phase.value, RecordPhase.recording);
      c.onClose();
    });
  });

  group('M28 list', () {
    test('server notes then notes on the phone, numbered in order, with their state', () async {
      when(() => voice.notes(any())).thenAnswer(
        (_) async => ApiSuccess<VoiceNoteListModel>(
          VoiceNoteListModel(
            data: [
              noteItem('v2', status: 'transcribing', language: 'hi', minute: 5),
              noteItem('v1', excerpt: 'Filter in room 2 was full of dust.'),
            ],
            meta: const ListMetaModel(),
          ),
        ),
      );
      await queue.addTyped(jobId: 'j1', text: 'Customer asked for a service plan');
      final player = FakePlayer();
      final c = VoiceNotesController(voice: voice, queue: queue, player: player, args: args, pollEvery: const Duration(hours: 1));
      await c.load();
      final rows = c.rows;
      expect(rows.map(c.title), ['Voice note 1', 'Voice note 2', 'Typed note 3']);
      expect(rows.map(c.statusText), ['Written', 'Writing…', 'Saved on phone']);
      expect(c.language(rows[1]), 'Hindi');
      expect(c.quote(rows[0]), '“Filter in room 2 was full of dust.”');
      expect(c.quote(rows[1]), isNull); // not written yet
      await c.onPlayTap(rows[0]);
      expect(player.played, ['https://x/v1.m4a']);
      expect(c.isPlaying(rows[0]), isTrue);
      await _ignoreApp(() => c.delete(rows[2]));
      expect(queue.notes, isEmpty);
      c.onClose();
    });
  });

  group('M29 note', () {
    VoiceNoteController open(VoiceNoteOutModel n) {
      when(() => voice.note(any())).thenAnswer((_) async => ApiSuccess<VoiceNoteOutModel>(n));
      return VoiceNoteController(
        voice: voice,
        player: FakePlayer(),
        args: args.note(n.id, 1),
        pollEvery: const Duration(hours: 1),
      );
    }

    test('shows the language it was written in, and a typed fix is saved', () async {
      final c = open(noteOut('v1', text: 'The filter in room 2 was full of dust.'));
      await c.load();
      expect(c.title, 'Voice note 1');
      expect(c.subtitle, 'Green Valley Clinic · 0:42');
      expect(c.languageLine, 'Gujarati, written in English');
      expect(c.reportText, 'The filter in room 2 was full of dust.');
      when(() => voice.edit(any(), any())).thenAnswer(
        (_) async => ApiSuccess<VoiceNoteOutModel>(noteOut('v1', text: 'The filter was full of dust.')),
      );
      c.onEditTap();
      expect(c.editing.value, isTrue);
      c.textController.text = 'The filter was full of dust.';
      await _ignoreApp(c.onSaveTap);
      verify(() => voice.edit('v1', 'The filter was full of dust.')).called(1);
      expect(c.reportText, 'The filter was full of dust.');
      c.onClose();
    });

    test('a note that was not clear says so', () async {
      final c = open(noteOut('v1', status: 'unclear', translatedTo: null));
      await c.load();
      expect(c.unclear, isTrue);
      expect(c.languageLine, 'Gujarati · not clear');
      c.onClose();
    });
  });
}
