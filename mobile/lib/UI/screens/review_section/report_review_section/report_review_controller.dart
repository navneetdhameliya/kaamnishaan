import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reports_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_dictation.dart';
import '../../../common_widgets/kn_toast.dart';

/// One tick box on "Ask for changes".
class ChangeOption {
  ChangeOption({required this.reason, required this.label, this.specific = false, bool checked = false})
      : checked = checked.obs;

  /// The server's reason: missing_photos, wrong_details, unclear_text, failed_check_not_explained, other.
  final String reason;
  final String label;

  /// Says exactly what (a photo the AI found missing), so its words go into the note for the technician.
  final bool specific;
  final RxBool checked;
}

/// M33 Report review: the proof at a glance (photos, checklist, voice notes), what the AI check found,
/// the words — then Approve, or Ask for changes with the reasons and a note for the technician.
class ReportReviewController extends GetxController {
  ReportReviewController({
    required this.reports,
    required this.jobs,
    required this.translation,
    required this.dictation,
    ReportArguments? args,
    DateTime Function()? clock,
  })  : args = args ?? Get.arguments as ReportArguments,
        _clock = clock ?? DateTime.now;

  final IReportsApiRepository reports;
  final IJobsApiRepository jobs;
  final TranslationService translation;

  /// Speak instead of typing (the microphone in the text box).
  final Dictation dictation;
  final ReportArguments args;
  final DateTime Function() _clock;

  final Rxn<ReportOutModel> report = Rxn<ReportOutModel>();
  final RxList<EvidenceOutModel> photos = <EvidenceOutModel>[].obs;
  final RxBool approving = false.obs;
  final RxBool sending = false.obs;

  // ---- ask for changes ---------------------------------------------------------------------
  final RxList<ChangeOption> options = <ChangeOption>[].obs;
  final TextEditingController note = TextEditingController();
  final RxnString changesError = RxnString();

  String get reportId => args.reportId!;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    dictation.cancel();
    note.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final results = await Future.wait([reports.report(reportId), jobs.evidence(args.jobId)]);
    final list = results[1].dataOrNull as EvidenceListModel?;
    if (list != null) {
      const order = {'before': 0, 'during': 1, 'after': 2};
      photos.assignAll(
        [...list.data]..sort((a, b) {
            final s = (order[a.stage] ?? 1).compareTo(order[b.stage] ?? 1);
            return s != 0 ? s : a.takenAt.compareTo(b.takenAt);
          }),
      );
    }
    final r = results[0].dataOrNull as ReportOutModel?;
    if (r == null) {
      final e = results[0].errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    report.value = r;
  }

  // ---- what it shows -----------------------------------------------------------------------

  String get subtitle => '${report.value?.job.customer ?? args.customer} · #${report.value?.number ?? ''}';

  String get title => report.value?.job.title ?? '';

  String get techName => report.value?.job.technician?.name ?? '';

  String get techFirst => techName.split(' ').first;

  /// "Ramesh Patel · Sat 31 Oct, 11:58 AM"
  String get byLine {
    final t = report.value?.submittedAt ?? report.value?.updatedAt;
    if (t == null) return techName;
    final day = DateFormat('EEE d MMM', translation.currentCode).format(t.toLocal());
    return [if (techName.isNotEmpty) techName, '$day, ${TimeUtils.clock(t, translation.currentCode)}'].join(' · ');
  }

  String get draftChip => report.value?.draftedBy == 'ai' ? LangKeys.reviewAiDraft.tr : LangKeys.reviewPlainDraft.tr;

  /// "Sent 10 min ago"
  String? get sentChip {
    final t = report.value?.submittedAt;
    if (t == null) return null;
    final m = _clock().difference(t.toLocal()).inMinutes;
    final ago = m < 1
        ? LangKeys.queueJustNow.tr
        : m < 60
            ? LangKeys.queueMinAgo.trParams({'n': '$m'})
            : m < 60 * 24
                ? LangKeys.queueHAgo.trParams({'n': '${m ~/ 60}'})
                : LangKeys.queueDaysAgo.trParams({'n': '${m ~/ (60 * 24)}'});
    return LangKeys.reviewSentAgo.trParams({'ago': ago});
  }

  int get photoCount {
    final p = report.value?.evidence.photos ?? const {};
    final n = p.values.fold<int>(0, (n, v) => n + ((v as num?)?.toInt() ?? 0));
    return n == 0 ? photos.length : n;
  }

  int get checksPassed => report.value?.evidence.checksPassed ?? 0;

  int get checksFailed => report.value?.evidence.checksFailed ?? 0;

  int get checksTotal => checksPassed + checksFailed;

  int get notes => report.value?.evidence.notes ?? 0;

  /// What the AI check wants a person to look at (missing photos, claims without proof).
  List<ReportFlagModel> get flags => report.value?.flags ?? const [];

  String flagText(ReportFlagModel f) =>
      f.kind == 'missing_evidence' ? LangKeys.reviewNoPhoto.trParams({'what': _cap(f.text)}) : f.text;

  String get flagsTitle => flags.length == 1
      ? LangKeys.reviewAiCheckOne.tr
      : LangKeys.reviewAiCheckMany.trParams({'n': '${flags.length}'});

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  bool get waiting => report.value?.status == 'pending_review';

  bool get approved => const {'approved', 'shared', 'acknowledged'}.contains(report.value?.status);

  bool get canEdit => report.value?.actions.contains('edit') ?? false;

  // ---- opening the proof -------------------------------------------------------------------

  Future<void> onPhotoTap(int index) async {
    final e = photos[index];
    await Get.toNamed(
      RoutesConstants.photoDetailsScreen,
      arguments: PhotoDetailArguments(
        jobId: args.jobId,
        evidenceId: e.id,
        customer: args.customer,
        index: index + 1,
        total: photos.length,
      ),
    );
  }

  Future<void> onPhotosTap() async {
    await Get.toNamed(
      RoutesConstants.photoGalleryScreen,
      arguments: PhotoArguments(jobId: args.jobId, stage: 'before', customer: args.customer),
    );
  }

  Future<void> onChecklistTap() async {
    await Get.toNamed(
      RoutesConstants.checklistsScreen,
      arguments: ChecklistArguments(jobId: args.jobId, customer: args.customer, coverUrl: args.coverUrl),
    );
  }

  Future<void> onVoiceTap() async {
    await Get.toNamed(
      RoutesConstants.voiceNotesScreen,
      arguments: VoiceArguments(jobId: args.jobId, customer: args.customer),
    );
  }

  Future<void> onEditTap() async {
    await Get.toNamed(RoutesConstants.reportEditorScreen, arguments: args);
    load();
  }

  // ---- approve -----------------------------------------------------------------------------

  Future<void> onApproveTap() async {
    approving.value = true;
    final result = await reports.approve(reportId);
    approving.value = false;
    final r = result.dataOrNull;
    if (r == null) return KnToast.error(result.errorOrNull!.message);
    report.value = r;
    KnToast.success(LangKeys.reviewApproved.tr);
    await Get.offNamed(RoutesConstants.reportPdfScreen, arguments: args);
  }

  void onSeePdfTap() => Get.toNamed(RoutesConstants.reportPdfScreen, arguments: args);

  void onShareTap() => Get.toNamed(RoutesConstants.shareReportScreen, arguments: args);

  // ---- ask for changes ---------------------------------------------------------------------

  /// The tick boxes: each missing photo the AI found (ticked), failed checks (ticked), the words,
  /// the details, and "Something else".
  void prepareChanges() {
    changesError.value = null;
    note.clear();
    options.assignAll([
      for (final f in flags.where((f) => f.kind == 'missing_evidence'))
        ChangeOption(
          reason: 'missing_photos',
          label: LangKeys.changesPhotoOf.trParams({'what': f.text}),
          specific: true,
          checked: true,
        ),
      if (!flags.any((f) => f.kind == 'missing_evidence'))
        ChangeOption(reason: 'missing_photos', label: LangKeys.changesMissingPhotos.tr),
      if (checksFailed > 0)
        ChangeOption(
          reason: 'failed_check_not_explained',
          label: LangKeys.changesFailedChecks.trParams({'n': '$checksFailed'}),
          specific: true,
          checked: true,
        ),
      ChangeOption(reason: 'unclear_text', label: LangKeys.changesUnclearText.tr),
      ChangeOption(reason: 'wrong_details', label: LangKeys.changesWrongDetails.tr),
      ChangeOption(reason: 'other', label: LangKeys.changesOther.tr),
    ]);
  }

  void onOptionTap(ChangeOption o) {
    o.checked.toggle();
    changesError.value = null;
  }

  bool get canSendChanges => options.any((o) => o.checked.value);

  /// Sends it back. The ticked specific items and the note become the note the technician reads.
  Future<bool> onSendChangesTap() async {
    final picked = options.where((o) => o.checked.value).toList();
    if (picked.isEmpty) {
      changesError.value = LangKeys.changesPickOne.tr;
      return false;
    }
    final typed = note.text.trim();
    if (picked.any((o) => o.reason == 'other') && typed.isEmpty) {
      changesError.value = LangKeys.changesNoteRequired.tr;
      return false;
    }
    final words = [
      ...picked.where((o) => o.specific).map((o) => o.label),
      if (typed.isNotEmpty) typed,
    ].join('. ');
    sending.value = true;
    final result = await reports.requestChanges(
      reportId,
      reasons: picked.map((o) => o.reason).toSet().toList(),
      note: words.isEmpty ? null : words,
    );
    sending.value = false;
    final r = result.dataOrNull;
    if (r == null) {
      final e = result.errorOrNull!;
      changesError.value = e.fields['note'] != null ? LangKeys.changesNoteRequired.tr : e.message;
      return false;
    }
    report.value = r;
    KnToast.success(LangKeys.changesSent.trParams({'name': techFirst}));
    return true;
  }
}
