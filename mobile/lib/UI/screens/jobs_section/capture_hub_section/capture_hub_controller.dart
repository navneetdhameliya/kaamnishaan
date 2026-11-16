import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/location_service.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
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
    this.queue,
    this.location,
    JobArguments? args,
  }) : args = args ?? Get.arguments as JobArguments;

  final IJobsApiRepository repository;
  final ISpeechService speech;
  final TranslationService translation;
  final PhotoQueueService? queue;
  final ILocationService? location;
  final JobArguments args;
  Worker? _sentWorker;
  Worker? _notesWorker;

  final Rxn<ProofModel> proof = Rxn<ProofModel>();
  final Rxn<JobOutModel> job = Rxn<JobOutModel>();
  final RxBool loading = false.obs;
  final RxBool starting = false.obs;

  /// The order the steps are shown in.
  static const order = ['before', 'during', 'after', 'checklist', 'voice'];

  static const photoStages = {'before', 'during', 'after'};

  @override
  void onInit() {
    super.onInit();
    load();
    final q = queue;
    if (q != null) {
      _sentWorker = ever(q.sent, (_) => load());
      _notesWorker = ever(q.notesSent, (_) => load());
    }
  }

  @override
  void onClose() {
    _sentWorker?.dispose();
    _notesWorker?.dispose();
    super.onClose();
  }

  /// Photos taken (or notes recorded) but still on the phone (no internet yet).
  int pendingFor(String stage) =>
      stage == 'voice' ? queue?.notesFor(args.id).length ?? 0 : queue?.countFor(args.id, stage) ?? 0;

  int get pendingCount => photoStages.fold(0, (n, s) => n + pendingFor(s));

  String get customer => job.value?.customer.name ?? args.customer ?? '';

  /// "AC not cooling · Room 2"
  String get subtitle {
    final j = job.value;
    return [j?.title ?? args.title, j?.site?.label].where((s) => s != null && s.isNotEmpty).join(' · ');
  }

  bool get notStarted => proof.value?.blockedBy == 'job_not_started';

  /// The server's steps, with photos still on the phone counted in (they count as taken).
  List<ProofStepModel> get steps {
    final all = proof.value?.steps ?? const [];
    return [
      for (final k in order)
        for (final s in all.where((s) => s.key == k))
          pendingFor(k) == 0
              ? s
              : ProofStepModel(
                  key: s.key,
                  count: s.count + pendingFor(k),
                  done: true,
                  requiredValue: s.requiredValue,
                  thumbs: s.thumbs,
                  total: s.total,
                ),
    ];
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
  String? get unlockHint => pendingCount > 0
      ? LangKeys.hubWaitingUpload.trParams({'count': '$pendingCount'})
      : switch (proof.value?.blockedBy) {
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
    final where = await location?.current();
    final result = await repository.start(args.id, lat: where?.lat, lng: where?.lng);
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

  /// "4 Lake Road · Room 2"
  String get place {
    final s = job.value?.site;
    return [s?.address, s?.label].where((p) => p != null && p.isNotEmpty).join(' · ');
  }

  /// Photo steps open the camera (M20), the checklist step the checklists (M24); voice notes and
  /// the report come in the next steps.
  void onStepTap(ProofStepModel step) {
    if (photoStages.contains(step.key)) {
      openCamera(step.key);
    } else if (step.key == 'checklist') {
      openChecklists();
    } else if (step.key == 'voice') {
      openVoice(step.count);
    } else {
      KnToast.info(LangKeys.commonComingSoon.tr);
    }
  }

  /// No notes yet: straight to the recorder (then the list); otherwise the notes list.
  Future<void> openVoice(int count) async {
    if (notStarted) return KnToast.info(LangKeys.hubStartFirst.tr);
    final voice = VoiceArguments(jobId: args.id, customer: customer, openListAfter: count == 0);
    await Get.toNamed(count == 0 ? RoutesConstants.voiceRecordScreen : RoutesConstants.voiceNotesScreen, arguments: voice);
    load();
  }

  Future<void> openChecklists() async {
    if (notStarted) return KnToast.info(LangKeys.hubStartFirst.tr);
    final e = job.value?.equipment;
    final equipment = [e?.type, job.value?.site?.label].where((p) => p != null && p.isNotEmpty).join(' · ');
    await Get.toNamed(
      RoutesConstants.checklistsScreen,
      arguments: ChecklistArguments(
        jobId: args.id,
        customer: customer,
        coverUrl: job.value?.coverUrl,
        equipment: equipment.isEmpty ? null : equipment,
      ),
    );
    load();
  }

  /// The camera button: the stage that is next, else "during".
  void onCaptureTap() {
    final next = nextKey;
    openCamera(next != null && photoStages.contains(next) ? next : 'during');
  }

  Future<void> openCamera(String stage) async {
    if (notStarted || proof.value == null) return KnToast.info(LangKeys.hubStartFirst.tr);
    await Get.toNamed(
      RoutesConstants.cameraScreen,
      arguments: PhotoArguments(
        jobId: args.id,
        stage: stage,
        customer: customer,
        prompts: proof.value?.shotPrompts ?? const [],
        place: place,
      ),
    );
    load();
  }

  void onMakeReportTap() => KnToast.info(LangKeys.commonComingSoon.tr);
}
