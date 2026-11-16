import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/camera_service.dart';
import '../../../../infrastructure/services/location_service.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
import '../../../../infrastructure/shared/app_logger.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_toast.dart';

/// A small picture in the strip: a photo on the server ([url]) or one still on the phone ([path]).
class CameraThumb {
  const CameraThumb({this.url, this.path});

  final String? url;
  final String? path;
}

/// M20 Camera: big shutter, the stage ("AFTER · photo 2"), the checklist hint for the next shot,
/// and the photos taken so far. Each photo is saved on the phone at once and sent in the background.
class CameraScreenController extends GetxController with WidgetsBindingObserver {
  CameraScreenController({
    required this.camera,
    required this.queue,
    required this.jobs,
    this.location,
    PhotoArguments? args,
    Future<bool> Function()? openSettings,
  })  : args = args ?? Get.arguments as PhotoArguments,
        _openSettings = openSettings ?? ph.openAppSettings;

  final ICameraService camera;
  final PhotoQueueService queue;
  final IJobsApiRepository jobs;
  final ILocationService? location;
  final PhotoArguments args;
  final Future<bool> Function() _openSettings;

  final Rxn<CameraOpenResult> status = Rxn<CameraOpenResult>();

  /// before, during or after; the gallery can switch it ("Add photo" under another stage).
  late final RxString stage = args.stage.obs;
  final RxBool showGuide = true.obs;
  final RxBool busy = false.obs;
  final RxBool flash = false.obs;
  final RxList<EvidenceOutModel> serverPhotos = <EvidenceOutModel>[].obs;
  final RxSet<String> takenSlots = <String>{}.obs;
  LatLng? _where;
  Worker? _sentWorker;

  /// Thumbnails shown in the strip.
  static const stripSize = 5;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    openCamera();
    loadPhotos();
    _sentWorker = ever(queue.sent, (_) => loadPhotos());
    location?.current().then((p) => _where = p);
    for (final p in args.prompts) {
      if (p.done) takenSlots.add(p.key);
    }
  }

  Future<void> openCamera() async => status.value = await camera.open();

  Future<void> loadPhotos() async {
    final result = await jobs.evidence(args.jobId);
    final list = result.dataOrNull;
    if (list != null) serverPhotos.assignAll(list.data);
  }

  List<PendingPhoto> get _pending => queue.items.where((p) => p.jobId == args.jobId).toList();

  int get stageCount =>
      serverPhotos.where((e) => e.stage == stage.value).length + _pending.where((p) => p.stage == stage.value).length;

  int get totalCount => serverPhotos.length + _pending.length;

  /// "AFTER · photo 2" — the number of the next photo.
  String get stageLabel => LangKeys.cameraStagePhoto.trParams({
        'stage': switch (stage.value) {
          'before' => LangKeys.cameraStageBefore.tr,
          'during' => LangKeys.cameraStageDuring.tr,
          _ => LangKeys.cameraStageAfter.tr,
        },
        'count': '${stageCount + 1}',
      });

  /// The next checklist shot for this stage that has no photo yet.
  ShotPromptModel? get prompt =>
      args.prompts.firstWhereOrNull((p) => p.stage == stage.value && !takenSlots.contains(p.key));

  /// The latest photos of this job, oldest first, the newest last.
  List<CameraThumb> get thumbs {
    final server = [...serverPhotos]..sort((a, b) => a.takenAt.compareTo(b.takenAt));
    final all = [
      for (final e in server) CameraThumb(url: e.thumbUrl ?? e.url),
      for (final p in _pending) CameraThumb(path: p.path),
    ];
    return all.length <= stripSize ? all : all.sublist(all.length - stripSize);
  }

  void onToggleGuide() => showGuide.toggle();

  Future<void> onShutterTap() async {
    if (busy.value || status.value != CameraOpenResult.ready) return;
    busy.value = true;
    flash.value = true;
    Timer(const Duration(milliseconds: 120), () => flash.value = false);
    final takenAt = DateTime.now();
    final path = await camera.takePicture();
    if (path == null) {
      busy.value = false;
      return KnToast.error(LangKeys.cameraFailed.tr);
    }
    final slot = args.single ? null : prompt?.key;
    try {
      final saved = await queue.add(
        jobId: args.jobId,
        stage: stage.value,
        sourcePath: path,
        takenAt: takenAt,
        lat: _where?.lat,
        lng: _where?.lng,
        shotSlot: slot,
      );
      if (slot != null) takenSlots.add(slot);
      if (args.single) {
        busy.value = false;
        Get.back<String>(result: saved.id);
        return;
      }
    } catch (e) {
      AppLogger.error('Saving the photo failed', error: e);
      KnToast.error(LangKeys.cameraFailed.tr);
    }
    busy.value = false;
  }

  void onDoneTap() => Get.back<bool>(result: true);

  void onCloseTap() => Get.back<bool>(result: true);

  Future<void> onGalleryTap() async {
    final picked = await Get.toNamed<String>(RoutesConstants.photoGalleryScreen, arguments: args.withStage(stage.value));
    if (picked != null) stage.value = picked;
  }

  Future<void> onOpenSettingsTap() async {
    try {
      await _openSettings();
    } catch (e) {
      AppLogger.error('Opening settings failed', error: e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      camera.close();
    } else if (state == AppLifecycleState.resumed) {
      openCamera(); // also picks up "Camera" turned on in settings
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _sentWorker?.dispose();
    camera.close();
    super.onClose();
  }
}
