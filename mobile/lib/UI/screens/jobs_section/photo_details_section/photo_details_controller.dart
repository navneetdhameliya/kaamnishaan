import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/share_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/share_rules.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M23 Photo details: the photo, its stage, when, who, where and notes. After the report is sent the
/// photo is locked (D-34): it can't be changed, only notes can be added.
class PhotoDetailsController extends GetxController {
  PhotoDetailsController({
    required this.jobs,
    required this.translation,
    required this.share,
    required this.session,
    PhotoDetailArguments? args,
  })
      : args = args ?? Get.arguments as PhotoDetailArguments;

  final IJobsApiRepository jobs;
  final TranslationService translation;
  final IShareService share;
  final SessionService session;
  final PhotoDetailArguments args;

  /// Fetching the photo for the share sheet.
  final RxBool sharing = false.obs;

  final Rxn<EvidenceDetailModel> photo = Rxn<EvidenceDetailModel>();
  final RxBool saving = false.obs;
  final TextEditingController noteController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    noteController.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final result = await jobs.photo(args.evidenceId!);
    final data = result.dataOrNull;
    if (data != null) {
      photo.value = data;
    } else {
      KnToast.error(result.errorOrNull!.message);
    }
  }

  String stageName(String stage) => switch (stage) {
        'before' => LangKeys.galleryBefore.tr,
        'during' => LangKeys.galleryDuring.tr,
        _ => LangKeys.galleryAfter.tr,
      };

  /// "BEFORE · photo 1 of 3"
  String get chip {
    final s = photo.value?.stage ?? 'before';
    final upper = switch (s) {
      'before' => LangKeys.cameraStageBefore.tr,
      'during' => LangKeys.cameraStageDuring.tr,
      _ => LangKeys.cameraStageAfter.tr,
    };
    return LangKeys.photoStageOf.trParams({'stage': upper, 'n': '${args.index}', 'total': '${args.total}'});
  }

  /// "31 Oct 2026 · 10:52 AM"
  String get taken {
    final t = photo.value?.takenAt;
    if (t == null) return '';
    final locale = translation.currentCode;
    return '${DateFormat('d MMM y', locale).format(t.toLocal())} · ${TimeUtils.clock(t, locale)}';
  }

  String? get latestNote {
    final notes = photo.value?.notes ?? const [];
    return notes.isEmpty ? null : notes.last.text;
  }

  bool get canDelete => photo.value?.canDelete ?? false;

  Future<void> onSaveNoteTap() async {
    final t = noteController.text.trim();
    if (t.isEmpty || saving.value) return;
    saving.value = true;
    final result = await jobs.addNote(args.evidenceId!, t);
    saving.value = false;
    if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
    noteController.clear();
    Get.back<void>(); // closes the note sheet
    await load();
  }

  Future<void> onDeleteTap() async {
    final result = await jobs.deletePhoto(args.evidenceId!);
    if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
    KnToast.success(LangKeys.photoDeleted.tr);
    Get.back<bool>(result: true);
  }

  /// The phone's share sheet with this photo (D-141): owners and managers, and technicians when the
  /// company lets them share. Anyone else hears why.
  Future<void> onShareTap() async {
    final p = photo.value;
    if (p == null || sharing.value) return;
    if (!ShareRules.maySharePhotos(session)) return KnToast.info(LangKeys.photoShareOffice.tr);
    sharing.value = true;
    final ok = await share.sharePictures([p.url], text: [args.customer, chip, taken].where((x) => x.isNotEmpty).join(' · '));
    sharing.value = false;
    if (!ok) KnToast.error(LangKeys.photoShareFailed.tr);
  }
}
