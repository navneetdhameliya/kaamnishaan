import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/share_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/share_rules.dart';
import '../../../../infrastructure/shared/photo_pairs.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M22 Before and after: one before and one after photo side by side with a line to drag.
/// Uses the pair already saved, else the same checklist shot, else the latest of each (D-60).
class PhotoPairController extends GetxController {
  PhotoPairController({
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

  /// Fetching the two photos for the share sheet.
  final RxBool sharing = false.obs;

  final Rxn<EvidenceOutModel> before = Rxn<EvidenceOutModel>();
  final Rxn<EvidenceOutModel> after = Rxn<EvidenceOutModel>();
  final RxnString pairId = RxnString();
  final RxString subject = ''.obs;
  final RxDouble split = 0.5.obs;
  final RxBool loaded = false.obs;
  final RxBool saving = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final result = await jobs.evidence(args.jobId);
    loaded.value = true;
    final list = result.dataOrNull;
    if (list == null) return KnToast.error(result.errorOrNull!.message);
    final chosen = ChosenPair.pick(list);
    before.value = chosen.before;
    after.value = chosen.after;
    pairId.value = chosen.saved?.id;
    subject.value = chosen.saved?.subject ?? '';
  }

  bool get ready => before.value != null && after.value != null;

  String get title => subject.value.isNotEmpty ? subject.value : (args.place ?? args.customer);

  String get dateLine {
    final t = after.value?.takenAt ?? before.value?.takenAt;
    return t == null ? args.customer : '${args.customer} · ${DateFormat('d MMM y', translation.currentCode).format(t.toLocal())}';
  }

  String timeOf(EvidenceOutModel? e) => e == null ? '' : TimeUtils.clock(e.takenAt, translation.currentCode);

  void onDrag(double fraction) => split.value = fraction.clamp(0.05, 0.95);

  Future<void> onRetakeTap() async {
    await Get.toNamed(
      RoutesConstants.cameraScreen,
      arguments: PhotoArguments(jobId: args.jobId, stage: 'after', customer: args.customer),
    );
    pairId.value = null;
    await load();
  }

  Future<void> onUseTap() async {
    if (!ready) return KnToast.info(LangKeys.pairNeedBoth.tr);
    if (pairId.value != null) return KnToast.success(LangKeys.pairUsed.tr);
    saving.value = true;
    final result = await jobs.addPair(
      jobId: args.jobId,
      beforeId: before.value!.id,
      afterId: after.value!.id,
      subject: args.place,
    );
    saving.value = false;
    final pair = result.dataOrNull;
    if (pair == null) return KnToast.error(result.errorOrNull!.message);
    pairId.value = pair.id;
    KnToast.success(LangKeys.pairUsed.tr);
    Get.back<bool>(result: true);
  }

  /// The phone's share sheet with the before photo, then the after photo (D-141); same rule as one photo.
  Future<void> onShareTap() async {
    if (sharing.value) return;
    if (!ready) return KnToast.info(LangKeys.pairNeedBoth.tr);
    if (!ShareRules.maySharePhotos(session)) return KnToast.info(LangKeys.photoShareOffice.tr);
    sharing.value = true;
    final ok = await share.sharePictures(
      [before.value!.url, after.value!.url],
      text: LangKeys.pairShareText.trParams({'what': title, 'when': dateLine}),
    );
    sharing.value = false;
    if (!ok) KnToast.error(LangKeys.photoShareFailed.tr);
  }
}
