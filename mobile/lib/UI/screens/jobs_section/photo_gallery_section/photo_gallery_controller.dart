import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_toast.dart';

/// One tile in the gallery: a photo on the server, or one still on the phone.
class GalleryPhoto {
  const GalleryPhoto({required this.takenAt, this.server, this.pending});

  final DateTime takenAt;
  final EvidenceOutModel? server;
  final PendingPhoto? pending;
}

/// M21 Photo gallery: the job's photos by stage, with the time each was taken. Photos still on the
/// phone show "Waiting to send" (or "Not sent" — tap to try again).
class PhotoGalleryController extends GetxController {
  PhotoGalleryController({required this.jobs, required this.queue, required this.translation, PhotoArguments? args})
      : args = args ?? Get.arguments as PhotoArguments;

  final IJobsApiRepository jobs;
  final PhotoQueueService queue;
  final TranslationService translation;
  final PhotoArguments args;

  static const stages = ['before', 'during', 'after'];

  final RxList<EvidenceOutModel> serverPhotos = <EvidenceOutModel>[].obs;
  final RxBool loaded = false.obs;
  late final RxString selected = args.stage.obs;
  final Map<String, GlobalKey> sectionKeys = {for (final s in stages) s: GlobalKey()};
  Worker? _sentWorker;

  @override
  void onInit() {
    super.onInit();
    load();
    _sentWorker = ever(queue.sent, (_) => load());
  }

  Future<void> load() async {
    final result = await jobs.evidence(args.jobId);
    loaded.value = true;
    final list = result.dataOrNull;
    if (list != null) {
      serverPhotos.assignAll(list.data);
    } else if (!result.errorOrNull!.isNetwork) {
      KnToast.error(result.errorOrNull!.message);
    }
  }

  List<GalleryPhoto> photosOf(String stage) {
    final out = [
      for (final e in serverPhotos.where((e) => e.stage == stage)) GalleryPhoto(takenAt: e.takenAt, server: e),
      for (final p in queue.items.where((p) => p.jobId == args.jobId && p.stage == stage))
        GalleryPhoto(takenAt: p.takenAt, pending: p),
    ];
    out.sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return out;
  }

  int get total => stages.fold(0, (n, s) => n + photosOf(s).length);

  String stageName(String stage) => switch (stage) {
        'before' => LangKeys.galleryBefore.tr,
        'during' => LangKeys.galleryDuring.tr,
        _ => LangKeys.galleryAfter.tr,
      };

  /// "10:52" — short, to fit on a photo.
  String timeOf(DateTime t) => DateFormat('h:mm', translation.currentCode).format(t.toLocal());

  void onTabTap(String stage) {
    selected.value = stage;
    final ctx = sectionKeys[stage]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250));
  }

  /// Opens the camera; it comes back here, and the list refreshes.
  Future<void> onTakePhotoTap([String? stage]) async {
    final target = stage ?? selected.value;
    if (Get.previousRoute == RoutesConstants.cameraScreen) {
      Get.back<String>(result: target); // came from the camera: go back to it, on this stage
      return;
    }
    await Get.toNamed(RoutesConstants.cameraScreen, arguments: args.withStage(target));
    load();
  }

  void onPhotoTap(GalleryPhoto photo) {
    final p = photo.pending;
    if (p != null && p.state == PendingState.failed) {
      queue.retry(p.id);
      return;
    }
    KnToast.info(LangKeys.commonComingSoon.tr); // M23 photo details come next
  }

  @override
  void onClose() {
    _sentWorker?.dispose();
    super.onClose();
  }
}
