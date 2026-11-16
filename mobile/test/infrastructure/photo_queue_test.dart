import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/photo_queue_service.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

void main() {
  late Directory tmp;
  late Directory folder;
  late MockFilesRepository files;
  late MockJobsRepository jobs;
  late StreamController<bool> online;
  late MockChecklistsRepository checklists;
  late MockVoiceRepository voice;

  setUpAll(() {
    registerFallbackValue(UploadKind.photo);
    registerFallbackValue(<int>[]);
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('kn_queue_');
    folder = Directory('${tmp.path}/pending_photos');
    files = MockFilesRepository();
    jobs = MockJobsRepository();
    online = StreamController<bool>.broadcast();
    checklists = MockChecklistsRepository();
    voice = MockVoiceRepository();
  });

  tearDown(() async {
    await online.close();
    tmp.deleteSync(recursive: true);
  });

  PhotoQueueService queue() => PhotoQueueService(
        files: files,
        jobs: jobs,
        checklists: checklists,
        voice: voice,
        folder: () async => folder,
        online: online.stream,
        retryEvery: const Duration(hours: 1),
      );

  String shot([String name = 'cam.jpg']) {
    final f = File('${tmp.path}/$name')..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    return f.path;
  }

  void uploads(ApiResult<String> Function() answer) => when(
        () => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')),
      ).thenAnswer((_) async => answer());

  void addPhoto(ApiResult<String> Function() answer) => when(
        () => jobs.addPhoto(
          jobId: any(named: 'jobId'),
          uploadId: any(named: 'uploadId'),
          stage: any(named: 'stage'),
          takenAt: any(named: 'takenAt'),
          clientUuid: any(named: 'clientUuid'),
          lat: any(named: 'lat'),
          lng: any(named: 'lng'),
          shotSlot: any(named: 'shotSlot'),
        ),
      ).thenAnswer((_) async => answer());

  const noInternet = ApiFailure<String>(ApiException(code: 'no_internet', message: 'offline'));

  test('a photo is kept on the phone first, then sent and removed', () async {
    uploads(() => const ApiSuccess<String>('up-1'));
    addPhoto(() => const ApiSuccess<String>('ev-1'));
    final q = await queue().init();
    final source = shot();
    final p = await q.add(jobId: 'j1', stage: 'after', sourcePath: source, lat: 21.1, lng: 72.8, shotSlot: 'filter');
    expect(File(source).existsSync(), isFalse); // moved into the app's own folder
    await q.process();
    expect(q.items, isEmpty);
    expect(File(p.path).existsSync(), isFalse);
    expect(q.sent.value, 1);
    verify(() => files.upload(kind: UploadKind.photo, bytes: any(named: 'bytes'), contentType: 'image/jpeg')).called(1);
    verify(
      () => jobs.addPhoto(
        jobId: 'j1',
        uploadId: 'up-1',
        stage: 'after',
        takenAt: any(named: 'takenAt'),
        clientUuid: p.id,
        lat: 21.1,
        lng: 72.8,
        shotSlot: 'filter',
      ),
    ).called(1);
    q.onClose();
  });

  test('no internet: the photo waits, survives a restart, and goes when the internet is back', () async {
    uploads(() => noInternet);
    final q = await queue().init();
    final p = await q.add(jobId: 'j1', stage: 'before', sourcePath: shot());
    await q.process();
    expect(q.items.single.state, PendingState.waiting);
    expect(q.items.single.tries, 0); // no internet does not count as a try
    q.onClose();

    // the app is closed and opened again
    final again = await queue().init();
    expect(again.items.single.id, p.id);
    expect(again.countFor('j1', 'before'), 1);
    uploads(() => const ApiSuccess<String>('up-2'));
    addPhoto(() => const ApiSuccess<String>('ev-1'));
    online.add(true);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(again.items, isEmpty);
    again.onClose();
  });

  test('a photo that was being sent when the app closed is sent again (same id, so no double)', () async {
    folder.createSync(recursive: true);
    final path = shot('x.jpg');
    File('${folder.path}/queue.json').writeAsStringSync(jsonEncode([
      {'id': 'abc', 'job_id': 'j1', 'stage': 'during', 'taken_at': '2026-10-31T10:00:00.000', 'path': path, 'state': 'sending'},
    ]));
    final q = await queue().init();
    expect(q.items.single.state, PendingState.waiting);
    uploads(() => const ApiSuccess<String>('up-3'));
    addPhoto(() => const ApiSuccess<String>('ev-1'));
    await q.process();
    verify(
      () => jobs.addPhoto(
        jobId: 'j1',
        uploadId: 'up-3',
        stage: 'during',
        takenAt: any(named: 'takenAt'),
        clientUuid: 'abc',
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        shotSlot: any(named: 'shotSlot'),
      ),
    ).called(1);
    q.onClose();
  });

  test('a refused photo is tried a few times, then shown as not sent; retry starts again', () async {
    uploads(() => const ApiSuccess<String>('up-4'));
    addPhoto(() => const ApiFailure<String>(ApiException(code: 'evidence_locked', message: 'Locked', statusCode: 409)));
    final q = await queue().init();
    await q.add(jobId: 'j1', stage: 'after', sourcePath: shot());
    for (var i = 0; i < PhotoQueueService.maxTries; i++) {
      await q.process();
    }
    expect(q.items.single.state, PendingState.failed);
    expect(q.items.single.error, 'Locked');
    await q.process(); // failed photos are left alone
    verify(() => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')))
        .called(PhotoQueueService.maxTries);
    addPhoto(() => const ApiSuccess<String>('ev-1'));
    await q.retry(q.items.single.id);
    expect(q.items, isEmpty);
    q.onClose();
  });

  test('photos go in the order they were taken, one at a time', () async {
    final order = <String>[];
    uploads(() => const ApiSuccess<String>('u'));
    when(
      () => jobs.addPhoto(
        jobId: any(named: 'jobId'),
        uploadId: any(named: 'uploadId'),
        stage: any(named: 'stage'),
        takenAt: any(named: 'takenAt'),
        clientUuid: any(named: 'clientUuid'),
        lat: any(named: 'lat'),
        lng: any(named: 'lng'),
        shotSlot: any(named: 'shotSlot'),
      ),
    ).thenAnswer((inv) async {
      order.add(inv.namedArguments[#stage] as String);
      return const ApiSuccess<String>('ev-1');
    });
    final q = await queue().init();
    await q.add(jobId: 'j1', stage: 'before', sourcePath: shot('a.jpg'));
    await q.add(jobId: 'j1', stage: 'during', sourcePath: shot('b.jpg'));
    await q.add(jobId: 'j1', stage: 'after', sourcePath: shot('c.jpg'));
    await q.process();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(order, ['before', 'during', 'after']);
    expect(q.items, isEmpty);
    q.onClose();
  });

  group('checklist answers (D-59)', () {
    void answers(ApiResult<SubmissionOutModel> Function() result) => when(
          () => checklists.answer(
            checklistId: any(named: 'checklistId'),
            questionId: any(named: 'questionId'),
            clientUuid: any(named: 'clientUuid'),
            value: any(named: 'value'),
            photoId: any(named: 'photoId'),
            signatureUploadId: any(named: 'signatureUploadId'),
          ),
        ).thenAnswer((_) async => result());

    const sub = SubmissionOutModel(
      id: 'c1', jobId: 'j1', name: 'HVAC', language: 'en', answered: 1, total: 2, status: 'in_progress',
      locked: false, questions: [],
    );

    test('an answer waits without internet, survives a restart, and a newer answer replaces it', () async {
      answers(() => const ApiFailure<SubmissionOutModel>(ApiException(code: 'no_internet', message: '')));
      final q = await queue().init();
      await q.addAnswer(jobId: 'j1', checklistId: 'c1', questionId: 'q1', value: 'yes');
      await q.addAnswer(jobId: 'j1', checklistId: 'c1', questionId: 'q1', value: 'no');
      expect(q.answersFor('c1')['q1']?.value, 'no');
      expect(q.answers.length, 1);
      q.onClose();

      final again = await queue().init();
      expect(again.answersFor('c1')['q1']?.value, 'no');
      answers(() => const ApiSuccess<SubmissionOutModel>(sub));
      await again.process();
      expect(again.answers, isEmpty);
      expect(again.answersSent.value, 1);
      again.onClose();
    });

    test('an answer that needs a photo is sent after the photo, with its server id', () async {
      uploads(() => noInternet);
      answers(() => const ApiSuccess<SubmissionOutModel>(sub));
      final q = await queue().init();
      final photo = await q.add(jobId: 'j1', stage: 'during', sourcePath: shot());
      await q.addAnswer(jobId: 'j1', checklistId: 'c1', questionId: 'q3', value: 'no', photoRef: photo.id);
      await q.process();
      expect(q.answers.single.state, PendingState.waiting); // the photo is not sent, so neither is the answer
      verifyNever(
        () => checklists.answer(
          checklistId: any(named: 'checklistId'),
          questionId: any(named: 'questionId'),
          clientUuid: any(named: 'clientUuid'),
          value: any(named: 'value'),
          photoId: any(named: 'photoId'),
          signatureUploadId: any(named: 'signatureUploadId'),
        ),
      );
      uploads(() => const ApiSuccess<String>('up'));
      addPhoto(() => const ApiSuccess<String>('ev-77'));
      await q.process();
      expect(q.items, isEmpty);
      expect(q.answers, isEmpty);
      verify(
        () => checklists.answer(
          checklistId: 'c1',
          questionId: 'q3',
          clientUuid: any(named: 'clientUuid'),
          value: 'no',
          photoId: 'ev-77',
          signatureUploadId: any(named: 'signatureUploadId'),
        ),
      ).called(1);
      q.onClose();
    });

    test('version 1 files (a plain list of photos) still load', () async {
      folder.createSync(recursive: true);
      final path = shot('old.jpg');
      File('${folder.path}/queue.json').writeAsStringSync(jsonEncode([
        {'id': 'old', 'job_id': 'j1', 'stage': 'before', 'taken_at': '2026-10-31T10:00:00.000', 'path': path},
      ]));
      final q = await queue().init();
      expect(q.items.single.id, 'old');
      expect(q.answers, isEmpty);
      q.onClose();
    });
  });

  group('voice and typed notes (D-61)', () {
    void addVoice(ApiResult<VoiceNoteOutModel> Function() result) => when(
          () => voice.addVoice(
            jobId: any(named: 'jobId'),
            uploadId: any(named: 'uploadId'),
            durationS: any(named: 'durationS'),
            recordedAt: any(named: 'recordedAt'),
            clientUuid: any(named: 'clientUuid'),
            languageHint: any(named: 'languageHint'),
          ),
        ).thenAnswer((_) async => result());

    void addTyped(ApiResult<VoiceNoteOutModel> Function() result) => when(
          () => voice.addTyped(jobId: any(named: 'jobId'), text: any(named: 'text'), clientUuid: any(named: 'clientUuid')),
        ).thenAnswer((_) async => result());

    String recording() => (File('${tmp.path}/rec.m4a')..writeAsBytesSync(const [1, 2, 3])).path;

    test('a recording waits on the phone without internet and survives a restart', () async {
      uploads(() => const ApiFailure<String>(ApiException(code: 'no_internet', message: '')));
      final q = await queue().init();
      final n = await q.addVoice(jobId: 'j1', sourcePath: recording(), durationS: 42, languageHint: 'gu');
      await q.process();
      expect(q.notes.single.state, PendingState.waiting);
      expect(q.notes.single.tries, 0); // no internet is not a try
      expect(File(n.path!).existsSync(), isTrue);
      q.onClose();

      final again = await queue().init();
      expect(again.notesFor('j1').single.languageHint, 'gu');
      expect(again.notesFor('j1').single.durationS, 42);
      again.onClose();
    });

    test('with internet the recording is uploaded as audio, then confirmed once with its id', () async {
      uploads(() => const ApiSuccess<String>('up-1'));
      addVoice(() => ApiSuccess<VoiceNoteOutModel>(noteOut('v1', status: 'transcribing')));
      final q = await queue().init();
      final n = await q.addVoice(jobId: 'j1', sourcePath: recording(), durationS: 12.5);
      await q.process();
      expect(q.notes, isEmpty);
      expect(q.notesSent.value, 1);
      expect(File(n.path!).existsSync(), isFalse);
      verify(() => files.upload(kind: UploadKind.audio, bytes: any(named: 'bytes'), contentType: 'audio/mp4')).called(1);
      verify(
        () => voice.addVoice(
          jobId: 'j1',
          uploadId: 'up-1',
          durationS: 12.5,
          recordedAt: any(named: 'recordedAt'),
          clientUuid: n.id,
          languageHint: null,
        ),
      ).called(1);
      q.onClose();
    });

    test('a typed note is sent as text; a note never sent can be removed', () async {
      addTyped(() => ApiSuccess<VoiceNoteOutModel>(noteOut('t1', kind: 'typed', text: 'Cleaned the filter')));
      final q = await queue().init();
      await q.addTyped(jobId: 'j1', text: 'Cleaned the filter');
      await q.process();
      expect(q.notes, isEmpty);
      verify(() => voice.addTyped(jobId: 'j1', text: 'Cleaned the filter', clientUuid: any(named: 'clientUuid'))).called(1);

      uploads(() => const ApiFailure<String>(ApiException(code: 'no_internet', message: '')));
      final n = await q.addVoice(jobId: 'j1', sourcePath: recording(), durationS: 3);
      await q.process();
      await q.removeNote(n.id);
      expect(q.notes, isEmpty);
      expect(File(n.path!).existsSync(), isFalse);
      q.onClose();
    });
  });
}
