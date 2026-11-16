import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_toast.dart';

/// M19 Capture hub: the job's proof steps (before, during, after photos, checklist, voice note),
/// what to do next, and when "Make report" unlocks. The server decides what is done (GET /jobs/{id}/proof).
class CaptureHubController extends GetxController {
  CaptureHubController({
    required this.repository,
    required this.speech,
    required this.translation,
    JobArguments? args,
  }) : args = args ?? Get.arguments as JobArguments;

  final IJobsApiRepository repository;
  final ISpeechService speech;
  final TranslationService translation;
  final JobArguments args;

  final Rxn<ProofModel> proof = Rxn<ProofModel>();
  final Rxn<JobOutModel> job = Rxn<JobOutModel>();
  final RxBool loading = false.obs;
  final RxBool starting = false.obs;

  /// The order the steps are shown in.
  static const order = ['before', 'during', 'after', 'checklist', 'voice'];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  String get customer => job.value?.customer.name ?? args.customer ?? '';

  /// "AC not cooling · Room 2"
  String get subtitle {
    final j = job.value;
    return [j?.title ?? args.title, j?.site?.label].where((s) => s != null && s.isNotEmpty).join(' · ');
  }

  bool get notStarted => proof.value?.blockedBy == 'job_not_started';

  List<ProofStepModel> get steps {
    final all = proof.value?.steps ?? const [];
    return [for (final k in order) ...all.where((s) => s.key == k)];
  }

  /// Steps that count: the checklist only when the job has one.
  List<ProofStepModel> get counted => steps.where((s) => s.key != 'checklist' || (s.total ?? 0) > 0).toList();

  int get doneCount => counted.where((s) => s.done).length;

  int get totalCount => counted.length;

  /// The step to do now: the first required one that is not done (none before the job starts).
  String? get nextKey {
    if (notStarted || proof.value?.locked == true) return null;
    for (final k in const ['before', 'after', 'checklist']) {
      final s = steps.firstWhereOrNull((s) => s.key == k);
      if (s != null && s.requiredValue && !s.done) return k;
    }
    return null;
  }

  String get headline => notStarted ? LangKeys.hubNotStarted.tr : LangKeys.hubYourProof.tr;

  String get subline {
    if (notStarted) return LangKeys.hubStartToBegin.tr;
    final left = totalCount - doneCount;
    return left <= 0 ? LangKeys.hubReady.tr : LangKeys.hubStepsLeft.trParams({'count': '$left'});
  }

  /// Under "Make report": what still blocks it.
  String? get unlockHint => switch (proof.value?.blockedBy) {
        'need_before_photo' => LangKeys.hubUnlockBefore.tr,
        'need_after_photo' => LangKeys.hubUnlockAfter.tr,
        'need_checklist' => LangKeys.hubUnlockChecklist.tr,
        'evidence_locked' => LangKeys.hubSentForReview.tr,
        _ => null,
      };

  Future<void> load() async {
    loading.value = proof.value == null;
    final (proofResult, jobResult) = await (repository.proof(args.id), repository.job(args.id)).wait;
    loading.value = false;
    if (proofResult.dataOrNull != null) proof.value = proofResult.dataOrNull;
    if (jobResult.dataOrNull != null) job.value = jobResult.dataOrNull;
    final error = proofResult.errorOrNull ?? jobResult.errorOrNull;
    if (error != null && !error.isNetwork) KnToast.error(error.message);
  }

  Future<void> onStartTap() async {
    if (starting.value) return;
    starting.value = true;
    final result = await repository.start(args.id);
    starting.value = false;
    if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
    job.value = result.dataOrNull;
    await load();
  }

  void onSpeakTap() {
    final next = nextKey == null ? subline : '${stepTitle(nextKey!)}: ${LangKeys.hubTakeNow.tr}';
    speech.speak(
      notStarted
          ? '$headline. $subline'
          : LangKeys.hubSpeak.trParams({'done': '$doneCount', 'total': '$totalCount', 'next': next}),
      languageCode: translation.currentCode,
    );
  }

  static String stepTitle(String key) => switch (key) {
        'before' => LangKeys.hubBefore.tr,
        'during' => LangKeys.hubDuring.tr,
        'after' => LangKeys.hubAfter.tr,
        'checklist' => LangKeys.hubChecklist.tr,
        _ => LangKeys.hubVoice.tr,
      };

  /// Camera (M20), checklist (M24), voice (M27) and the report come in the next steps.
  void onStepTap([ProofStepModel? step]) => KnToast.info(LangKeys.commonComingSoon.tr);
}
