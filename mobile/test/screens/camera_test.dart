import 'dart:io';

import 'package:flutter/widgets.dart' show AppLifecycleState, Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/camera_section/camera_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/capture_hub_section/capture_hub_controller.dart';
import 'package:kaamnishaan/UI/screens/jobs_section/photo_gallery_section/photo_gallery_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/camera_service.dart';
import 'package:kaamnishaan/infrastructure/services/photo_queue_service.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/shared/job_arguments.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

EvidenceOutModel _photo(String id, String stage, int minute) => EvidenceOutModel(
      id: id,
      jobId: 'j1',
      stage: stage,
      url: 'https://x/$id.jpg',
      thumbUrl: 'https://x/$id-t.jpg',
      size: 100,
      processing: 'ready',
      takenAt: DateTime(2026, 10, 31, 10, minute),
      takenBy: const PersonRefModel(id: 'u1', name: 'Ramesh'),
      locked: false,
      notesCount: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late MockJobsRepository jobs;
  late MockFilesRepository files;
  late PhotoQueueService queue;
  late TranslationService translation;

  setUpAll(() {
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
    tmp = Directory.systemTemp.createTempSync('kn_cam_');
    jobs = MockJobsRepository();
    files = MockFilesRepository();
    // no internet in these tests: photos stay on the phone
    when(() => files.upload(kind: any(named: 'kind'), bytes: any(named: 'bytes'), contentType: any(named: 'contentType')))
        .thenAnswer((_) async => const ApiFailure<String>(ApiException(code: 'no_internet', message: '')));
    when(() => jobs.evidence(any())).thenAnswer(
      (_) async => ApiSuccess<EvidenceListModel>(
        EvidenceListModel(
          data: [_photo('e1', 'before', 52), _photo('e2', 'during', 20), _photo('e3', 'after', 41)],
          meta: const ListMetaModel(),
          pairs: const [],
        ),
      ),
    );
    queue = await PhotoQueueService(
      files: files,
      jobs: jobs,
      folder: () async => Directory('${tmp.path}/pending'),
      retryEvery: const Duration(hours: 1),
    ).init();
  });

  tearDown(() async {
    await queue.process(); // a send started by the test may still be using the folder
    queue.onClose();
    tmp.deleteSync(recursive: true);
  });

  const prompts = [
    ShotPromptModel(stage: 'after', key: 'filter', prompt: 'Show the clean filter up close', done: false),
    ShotPromptModel(stage: 'after', key: 'unit', prompt: 'Show the outdoor unit', done: false),
  ];

  group('M20 camera', () {
    CameraScreenController camera(FakeCamera cam) => CameraScreenController(
          camera: cam,
          queue: queue,
          jobs: jobs,
          location: FakeLocation((lat: 21.17, lng: 72.83)),
          args: const PhotoArguments(jobId: 'j1', stage: 'after', customer: 'Green Valley Clinic', prompts: prompts),
          openSettings: () async => true,
        );

    test('each photo is saved on the phone with the stage, place and checklist shot', () async {
      final c = camera(FakeCamera(folder: tmp));
      c.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(c.status.value, CameraOpenResult.ready);
      expect(c.stageLabel, 'AFTER · photo 2'); // one after photo on the server already
      expect(c.prompt?.prompt, 'Show the clean filter up close');
      await c.onShutterTap();
      final saved = queue.items.single;
      expect((saved.jobId, saved.stage, saved.shotSlot, saved.lat), ('j1', 'after', 'filter', 21.17));
      expect(c.prompt?.key, 'unit'); // next hint
      expect(c.stageLabel, 'AFTER · photo 3');
      expect(c.totalCount, 4);
      expect(c.thumbs.last.path, saved.path);
      c.onClose();
    });

    test('no camera permission shows "Camera is off"', () async {
      final c = camera(FakeCamera(folder: tmp, result: CameraOpenResult.denied));
      c.onInit();
      await Future<void>.delayed(Duration.zero);
      expect(c.status.value, CameraOpenResult.denied);
      await c.onShutterTap();
      expect(queue.items, isEmpty);
      c.onClose();
    });

    test('leaving the app closes the camera; coming back opens it again', () async {
      final cam = FakeCamera(folder: tmp);
      final c = camera(cam)..onInit();
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(cam.closed, isTrue);
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(cam.closed, isFalse);
      c.onClose();
    });
  });

  test('M21 gallery: server photos and photos on the phone, by stage and time', () async {
    final pending = await queue.add(jobId: 'j1', stage: 'after', sourcePath: (File('${tmp.path}/a.jpg')..writeAsBytesSync([1])).path);
    final c = PhotoGalleryController(
      jobs: jobs,
      queue: queue,
      translation: translation,
      args: const PhotoArguments(jobId: 'j1', stage: 'before', customer: 'Green Valley Clinic'),
    );
    await c.load();
    expect(c.total, 4);
    final after = c.photosOf('after');
    expect(after.first.server?.id, 'e3');
    expect(after.last.pending?.id, pending.id);
    expect(c.photosOf('before').single.server?.id, 'e1');
  });

  test('M19 counts photos still on the phone as taken, and says they wait for internet', () async {
    when(() => jobs.proof(any())).thenAnswer((_) async => ApiSuccess<ProofModel>(proofData()));
    when(() => jobs.job(any())).thenAnswer((_) async => ApiSuccess<JobOutModel>(jobOut(status: 'in_progress')));
    final hub = CaptureHubController(
      repository: jobs,
      speech: FakeSpeech(),
      translation: translation,
      queue: queue,
      args: const JobArguments(id: 'j1'),
    );
    await hub.load();
    expect(hub.nextKey, 'after');
    await queue.add(jobId: 'j1', stage: 'after', sourcePath: (File('${tmp.path}/b.jpg')..writeAsBytesSync([1])).path);
    final after = hub.steps.firstWhere((s) => s.key == 'after');
    expect((after.count, after.done), (1, true));
    expect(hub.nextKey, 'checklist');
    expect(hub.unlockHint, '1 saved on phone, sending when online');
  });
}
