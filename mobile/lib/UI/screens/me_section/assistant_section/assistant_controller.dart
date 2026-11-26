import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/assistant_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_dictation.dart';
import '../../../common_widgets/kn_toast.dart';

/// A quick question chip: [label] on the chip, [text] goes in the box (and is sent when [send]).
class AskChip {
  const AskChip(this.key, this.label, this.text, {this.send = true});

  final String key;
  final String label;
  final String text;
  final bool send;
}

/// M36 Ask KaamNishaan AI (owners and managers): questions about the company's own jobs, answered
/// with the reports and jobs they came from. At the plan's monthly limit, chat pauses.
class AssistantController extends GetxController {
  AssistantController({
    required this.assistant,
    required this.translation,
    required this.session,
    required this.dictation,
  });

  final IAssistantApiRepository assistant;
  final TranslationService translation;
  final SessionService session;

  /// Speak instead of typing (the microphone in the text box).
  final Dictation dictation;

  final RxList<AssistantMessageOutModel> messages = <AssistantMessageOutModel>[].obs;
  final RxBool loading = true.obs;
  final RxBool sending = false.obs;
  final RxBool available = true.obs;
  final RxBool paused = false.obs;

  /// The paused card is showing (until "Not now").
  final RxBool pausedCard = false.obs;
  final RxInt used = 0.obs;
  final RxnInt limit = RxnInt();
  final Rxn<DateTime> renewsAt = Rxn<DateTime>();

  final TextEditingController input = TextEditingController();
  final RxString draft = ''.obs;
  final ScrollController scroll = ScrollController();

  @override
  void onInit() {
    super.onInit();
    input.addListener(() => draft.value = input.text);
    load();
  }

  @override
  void onClose() {
    dictation.cancel();
    input.dispose();
    scroll.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final result = await assistant.chat();
    loading.value = false;
    final d = result.dataOrNull;
    if (d == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    messages.assignAll(d.data);
    available.value = d.available;
    used.value = d.used;
    limit.value = d.limit;
    renewsAt.value = d.renewsAt;
    paused.value = d.paused;
    pausedCard.value = d.paused;
    _toEnd();
  }

  List<AskChip> get chips => [
        AskChip('last', LangKeys.aiChipLast.tr, LangKeys.aiChipLastText.tr, send: false),
        AskChip('missing', LangKeys.aiChipMissing.tr, LangKeys.aiChipMissingText.tr),
        AskChip('week', LangKeys.aiChipWeek.tr, LangKeys.aiChipWeekText.tr),
      ];

  bool get canAsk => available.value && !paused.value;

  bool get canSend => canAsk && !sending.value && draft.value.trim().isNotEmpty;

  /// "Your company used this month's 200 AI questions. It starts again on 1 Dec."
  String get pausedBody => LangKeys.aiPausedBody.trParams({
        'n': '${limit.value ?? used.value}',
        'date': renewsAt.value == null ? '' : DateFormat('d MMM', translation.currentCode).format(renewsAt.value!.toLocal()),
      });

  String get usedLine => LangKeys.aiUsed.trParams({'a': '${used.value}', 'b': '${limit.value ?? '∞'}'});

  double get usedFraction {
    final l = limit.value;
    return l == null || l == 0 ? 0 : (used.value / l).clamp(0.0, 1.0);
  }

  /// "From 1 report · 3 photos"
  String? sourcesLine(AssistantMessageOutModel m) {
    final reports = m.reports?.length ?? 0;
    final jobs = m.jobs?.length ?? 0;
    final photos = m.photoCount ?? 0;
    final parts = [
      if (reports > 0) reports == 1 ? LangKeys.aiOneReport.tr : LangKeys.aiNReports.trParams({'n': '$reports'}),
      if (reports == 0 && jobs > 0) jobs == 1 ? LangKeys.aiOneJob.tr : LangKeys.aiNJobs.trParams({'n': '$jobs'}),
      if (photos > 0) LangKeys.aiNPhotos.trParams({'n': '$photos'}),
    ];
    return parts.isEmpty ? null : LangKeys.aiFrom.trParams({'sources': parts.join(' · ')});
  }

  /// "12 Aug · Approved"
  String reportLine(SourceReportModel r) {
    final status = switch (r.status) {
      'approved' => LangKeys.myreportsApproved.tr,
      'shared' || 'acknowledged' => LangKeys.myreportsApprovedSent.tr,
      'pending_review' => LangKeys.myreportsWaiting.tr,
      'changes_requested' => LangKeys.myreportsChanges.tr,
      _ => LangKeys.myreportsDraft.tr,
    };
    return '${DateFormat('d MMM', translation.currentCode).format(r.at.toLocal())} · $status';
  }

  /// "Missing: photo while working, voice note", or "All proof is in".
  String missingLine(SourceJobModel j) {
    if (j.missing.isEmpty) return LangKeys.aiAllDone.tr;
    final words = j.missing.map(
      (s) => switch (s) {
        'before' => LangKeys.aiStepBefore.tr,
        'during' => LangKeys.aiStepDuring.tr,
        'after' => LangKeys.aiStepAfter.tr,
        'checklists' => LangKeys.aiStepChecklists.tr,
        _ => LangKeys.aiStepVoice.tr,
      },
    );
    return LangKeys.aiMissing.trParams({'steps': words.join(', ')});
  }

  // ---- asking ------------------------------------------------------------------------------

  Future<void> onChip(AskChip c) async {
    if (!canAsk) return;
    input.text = c.text;
    input.selection = TextSelection.collapsed(offset: input.text.length);
    if (c.send) await onSend();
  }

  Future<void> onSend() async {
    final text = input.text.trim();
    if (text.isEmpty || sending.value) return;
    if (!canAsk) {
      pausedCard.value = paused.value;
      return;
    }
    sending.value = true;
    final mine = AssistantMessageOutModel(id: 'local', role: 'user', text: text, at: DateTime.now());
    messages.add(mine);
    input.clear();
    _toEnd();
    final result = await assistant.ask(text);
    sending.value = false;
    final d = result.dataOrNull;
    if (d == null) {
      messages.remove(mine);
      final e = result.errorOrNull!;
      if (e.code == 'ai_limit_reached') {
        paused.value = pausedCard.value = true;
        final details = e.details;
        if (details['limit'] is int) limit.value = details['limit'] as int;
        if (details['used'] is int) used.value = details['used'] as int;
      } else if (e.code == 'assistant_unavailable') {
        available.value = false;
      } else {
        input.text = text; // keep it to try again
      }
      if (e.code != 'ai_limit_reached') KnToast.error(e.message);
      return;
    }
    messages
      ..remove(mine)
      ..addAll([d.question, d.answer]);
    used.value = d.used;
    limit.value = d.limit;
    paused.value = d.paused;
    _toEnd();
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  void onNotNow() => pausedCard.value = false;

  bool get isOwner => session.me.value?.role == 'owner';

  /// The owner sees the plans; a manager is asked to tell the owner.
  Future<void> onUpgradeTap() async {
    if (!isOwner) return KnToast.info(LangKeys.aiOwnerUpgrade.tr);
    await Get.toNamed<void>(RoutesConstants.billingScreen);
  }

  Future<void> onReportTap(SourceReportModel r) async {
    final args = ReportArguments(jobId: r.jobId, customer: r.customer, reportId: r.id, coverUrl: r.coverUrl);
    await Get.toNamed<void>(
      r.status == 'pending_review' ? RoutesConstants.reportReviewScreen : RoutesConstants.reportPdfScreen,
      arguments: args,
    );
  }

  Future<void> onJobTap(SourceJobModel j) async {
    await Get.toNamed<void>(RoutesConstants.jobDetailsScreen, arguments: JobArguments(id: j.id, customer: j.customer, title: j.title));
  }

  /// The camera tile under "Missing: …" opens the job's proof screen, to add what is missing.
  Future<void> onMissingTap(SourceJobModel j) async {
    await Get.toNamed<void>(RoutesConstants.captureHubScreen, arguments: JobArguments(id: j.id, customer: j.customer, title: j.title));
  }
}
