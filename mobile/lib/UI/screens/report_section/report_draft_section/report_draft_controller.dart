import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reports_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/photo_pairs.dart';
import '../../../common_widgets/kn_toast.dart';

/// M31 Report draft: what the AI wrote from the proof, what is still missing, and "Send to manager".
/// After sending it is shown read-only with its review state.
class ReportDraftController extends GetxController {
  ReportDraftController({
    required this.reports,
    required this.jobs,
    required this.session,
    required this.speech,
    required this.translation,
    ReportArguments? args,
  }) : args = args ?? Get.arguments as ReportArguments;

  final IReportsApiRepository reports;
  final IJobsApiRepository jobs;
  final SessionService session;
  final ISpeechService speech;
  final TranslationService translation;
  final ReportArguments args;

  final Rxn<ReportOutModel> report = Rxn<ReportOutModel>();
  final Rx<ChosenPair> pair = const ChosenPair().obs;
  final RxBool sending = false.obs;

  String get reportId => args.reportId!;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    speech.stop();
    super.onClose();
  }

  Future<void> load() async {
    final results = await Future.wait([reports.report(reportId), jobs.evidence(args.jobId)]);
    final r = results[0].dataOrNull as ReportOutModel?;
    final list = results[1].dataOrNull as EvidenceListModel?;
    if (list != null) pair.value = ChosenPair.pick(list);
    if (r == null) {
      final e = results[0].errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    report.value = r;
  }

  bool get canEdit => report.value?.actions.contains('edit') ?? false;

  bool get canSend => report.value?.actions.contains('submit') ?? false;

  String get title => canEdit ? LangKeys.reportDraftTitle.tr : LangKeys.reportTitle.tr;

  String get subtitle =>
      LangKeys.reportSubtitle.trParams({'customer': report.value?.job.customer ?? args.customer, 'number': _number});

  String get _number => report.value?.number ?? '';

  String get companyName => session.me.value?.company?.name ?? '';

  String? get companyLogo => session.me.value?.company?.logoUrl;

  String get language => (report.value?.language ?? 'en').split('-').first.toUpperCase();

  /// "Ramesh Patel · 31 Oct 2026"
  String get byLine {
    final r = report.value;
    if (r == null) return '';
    final date = DateFormat('d MMM y', translation.currentCode).format(r.updatedAt.toLocal());
    final who = r.job.technician?.name;
    return who == null ? date : '$who · $date';
  }

  String? get technicianAvatar => report.value?.job.technician?.avatarUrl;

  int get photoCount {
    final p = report.value?.evidence.photos ?? const {};
    return p.values.fold<int>(0, (n, v) => n + ((v as num?)?.toInt() ?? 0));
  }

  int get answerCount {
    final e = report.value?.evidence;
    return e == null ? 0 : e.checksPassed + e.checksFailed;
  }

  /// "6 photos, 12 answers and 2 voice notes"
  String get proofText {
    final e = report.value?.evidence;
    final parts = [
      LangKeys.reportCountPhotos.trParams({'n': '$photoCount'}),
      if (answerCount > 0) LangKeys.reportCountAnswers.trParams({'n': '$answerCount'}),
      if ((e?.notes ?? 0) > 0) LangKeys.reportCountNotes.trParams({'n': '${e!.notes}'}),
    ];
    final joined = parts.length == 1
        ? parts.single
        : '${parts.sublist(0, parts.length - 1).join(', ')} ${LangKeys.reportAnd.tr} ${parts.last}';
    final key = report.value?.draftedBy == 'ai' ? LangKeys.reportDraftedAi : LangKeys.reportDraftedPlain;
    return key.trParams({'proof': joined});
  }

  /// Proof the AI says is missing ("after photo of outdoor unit"); only while it can still be fixed.
  List<ReportFlagModel> get missing =>
      canEdit ? (report.value?.flags ?? const []).where((f) => f.kind == 'missing_evidence').toList() : const [];

  /// The review state once sent (null while it is a draft).
  String? get stateText => switch (report.value?.status) {
        'pending_review' => LangKeys.reportWaitingReview.tr,
        'changes_requested' => LangKeys.reportChangesAsked.tr,
        'approved' || 'shared' || 'acknowledged' => LangKeys.reportApproved.tr,
        _ => null,
      };

  /// The latest note from the manager when changes were asked.
  String? get changeNote {
    final r = report.value;
    if (r == null || r.status != 'changes_requested' || r.changeRequests.isEmpty) return null;
    return r.changeRequests.last.note;
  }

  // ---- actions -----------------------------------------------------------------------------

  /// Reads the report out loud in its language.
  Future<void> onSpeakTap() async {
    final r = report.value;
    if (r == null) return;
    final words = [r.summary, r.workDone, r.advice].whereType<String>().where((s) => s.trim().isNotEmpty);
    await speech.speak(words.join('\n'), languageCode: r.language);
  }

  Future<void> onEditTap() async {
    await speech.stop();
    await Get.toNamed(RoutesConstants.reportEditorScreen, arguments: args);
    load();
  }

  /// "Take photo" for missing proof. When the technician has not changed the words, the report is
  /// made again with the new photo; otherwise their words are kept and only the photo is added.
  Future<void> onTakePhotoTap(ReportFlagModel flag) async {
    final stage = flag.text.toLowerCase().contains('before') ? 'before' : 'after';
    final before = photoCount;
    await Get.toNamed(
      RoutesConstants.cameraScreen,
      arguments: PhotoArguments(jobId: args.jobId, stage: stage, customer: args.customer),
    );
    final r = report.value;
    final edited = r?.sectionSources.values.contains('technician') ?? true;
    final list = (await jobs.evidence(args.jobId)).dataOrNull;
    final added = (list?.data.length ?? before) > before;
    if (added && !edited) {
      KnToast.info(LangKeys.reportRedraftAfterPhoto.tr);
      await Get.offNamed(RoutesConstants.reportMakingScreen, arguments: args.remake);
      return;
    }
    load();
  }

  Future<void> onSendTap() async {
    sending.value = true;
    final result = await reports.submit(reportId);
    sending.value = false;
    final r = result.dataOrNull;
    if (r == null) {
      final e = result.errorOrNull!;
      if (e.code == 'section_empty') {
        KnToast.error(LangKeys.reportEmptySection.tr);
        return onEditTap();
      }
      return KnToast.error(e.message);
    }
    report.value = r;
    await Get.offNamed(RoutesConstants.reportSentScreen, arguments: args);
  }
}
