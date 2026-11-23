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
import 'custom_widgets/pair_picker_sheet.dart';

/// M22 Before and after: one before and one after photo side by side with a line to drag.
/// Uses the pair already saved, else the same checklist shot, else the latest of each (D-60);
/// "Choose photos" picks another before and after by hand (D-144).
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

  /// Every photo of the job, for "Choose photos".
  final RxList<EvidenceOutModel> photos = <EvidenceOutModel>[].obs;

  /// The photos of the pair saved for the report, to tell when the shown pair differs from it.
  String? _savedBefore;
  String? _savedAfter;

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
    photos.assignAll(list.data);
    final chosen = ChosenPair.pick(list);
    before.value = chosen.before;
    after.value = chosen.after;
    pairId.value = chosen.saved?.id;
    _savedBefore = chosen.saved?.before.id;
    _savedAfter = chosen.saved?.after.id;
    subject.value = chosen.saved?.subject ?? '';
  }

  bool get ready => before.value != null && after.value != null;

  /// The pair on screen is the one saved for the report.
  bool get isSaved => pairId.value != null && before.value?.id == _savedBefore && after.value?.id == _savedAfter;

  /// The job's [stage] photos that can be shown, newest first.
  List<EvidenceOutModel> choices(String stage) =>
      photos.where((e) => e.stage == stage && e.processing != 'failed').toList()
        ..sort((a, b) => b.takenAt.compareTo(a.takenAt));

  /// "Choose photos": pick another before and after by hand.
  void onChooseTap() {
    if (choices('before').isEmpty || choices('after').isEmpty) return KnToast.info(LangKeys.pairNeedBoth.tr);
    showPairPickerSheet(this);
  }

  void onPick(EvidenceOutModel e) => (e.stage == 'before' ? before : after).value = e;

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
    if (isSaved) return KnToast.success(LangKeys.pairUsed.tr);
    saving.value = true;
    final old = pairId.value;
    if (old != null) {
      // one pair per report from the app: the new choice replaces the old one
      final removed = await jobs.deletePair(old);
      if (removed.errorOrNull case final e?) {
        saving.value = false;
        return KnToast.error(e.message);
      }
      pairId.value = null;
    }
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
    _savedBefore = pair.before.id;
    _savedAfter = pair.after.id;
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
