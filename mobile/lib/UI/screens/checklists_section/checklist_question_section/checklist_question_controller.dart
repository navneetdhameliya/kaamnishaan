import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/checklists_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_dictation.dart';
import '../../../common_widgets/kn_toast.dart';
import 'custom_widgets/ask_manager_sheet.dart';

/// M25 one checklist question at a time, big answers, read aloud. Answers are kept on the phone and
/// sent in the background (D-59); a "photo needed" answer waits for its photo. "Show if" rules are
/// followed on the phone too, so the right questions appear without internet.
class ChecklistQuestionController extends GetxController {
  ChecklistQuestionController({
    required this.checklists,
    required this.files,
    required this.jobs,
    required this.queue,
    required this.speech,
    required this.translation,
    required this.dictation,
    ChecklistArguments? args,
    this.advanceDelay = const Duration(milliseconds: 250),
  }) : args = args ?? Get.arguments as ChecklistArguments;

  final IChecklistsApiRepository checklists;
  final IFilesApiRepository files;

  /// "Not sure? Ask your manager" sends the question to the office.
  final IJobsApiRepository jobs;
  final PhotoQueueService queue;
  final ISpeechService speech;
  final TranslationService translation;

  /// Speak instead of typing (the microphone in the text box).
  final Dictation dictation;
  final ChecklistArguments args;
  final Duration advanceDelay;

  final Rxn<SubmissionOutModel> submission = Rxn<SubmissionOutModel>();
  final RxnString currentId = RxnString();

  /// Answers chosen that still wait for their photo (not sent yet).
  final RxMap<String, Object?> drafts = <String, Object?>{}.obs;
  final RxBool photoNeeded = false.obs;
  final RxBool saving = false.obs;
  final TextEditingController textController = TextEditingController();

  /// The technician's note for the manager, and whether it is being sent.
  final TextEditingController askNote = TextEditingController();
  final RxBool asking = false.obs;
  Worker? _sentWorker;

  String get checklistId => args.checklistId!;

  @override
  void onInit() {
    super.onInit();
    load();
    _sentWorker = ever(queue.answersSent, (_) => load());
  }

  @override
  void onClose() {
    dictation.cancel();
    _sentWorker?.dispose();
    textController.dispose();
    askNote.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final result = await checklists.submission(checklistId);
    final data = result.dataOrNull;
    if (data == null) {
      if (!result.errorOrNull!.isNetwork) KnToast.error(result.errorOrNull!.message);
      return;
    }
    submission.value = data;
    if (currentId.value == null || shown.every((q) => q.id != currentId.value)) {
      currentId.value = (shown.firstWhereOrNull((q) => !isComplete(q)) ?? shown.firstOrNull)?.id;
      _fillText();
    }
  }

  List<QuestionOutModel> get _all => submission.value?.questions ?? const [];

  Map<String, PendingAnswer> get _pending => queue.answersFor(checklistId);

  bool get locked => submission.value?.locked ?? false;

  /// The answer as the phone knows it: chosen, waiting to send, or on the server.
  Object? valueOf(QuestionOutModel q) =>
      drafts.containsKey(q.id) ? drafts[q.id] : (_pending[q.id]?.value ?? q.answer?.value);

  bool hasPhoto(QuestionOutModel q) => q.answer?.photo != null || _pending[q.id]?.photoRef != null;

  static bool needsPhoto(QuestionOutModel q, Object? value) {
    final v = '$value'.toLowerCase();
    return q.type == 'photo' ||
        q.photoRule == 'always' ||
        (q.photoRule == 'if_no' && v == 'no') ||
        (q.photoRule == 'if_fail' && v == 'fail');
  }

  bool isComplete(QuestionOutModel q) {
    if (q.type == 'signature') return q.answer?.signatureUrl != null;
    if (q.type == 'photo') return hasPhoto(q);
    final v = valueOf(q);
    if (v == null || '$v'.isEmpty || drafts.containsKey(q.id)) return false;
    return !needsPhoto(q, v) || hasPhoto(q);
  }

  /// Same rule as the server: shown when the earlier question's answer equals the condition.
  bool isShown(QuestionOutModel q, [int depth = 0]) {
    final cond = q.condition;
    if (cond == null || depth > 20) return true;
    final dep = _all.firstWhereOrNull((x) => x.id == '${cond['question_id']}');
    if (dep == null || !isShown(dep, depth + 1)) return false;
    final v = valueOf(dep);
    return v != null && '$v'.toLowerCase() == '${cond['equals']}'.toLowerCase();
  }

  List<QuestionOutModel> get shown => _all.where((q) => isShown(q)).toList();

  QuestionOutModel? get current => shown.firstWhereOrNull((q) => q.id == currentId.value);

  int get position => shown.indexWhere((q) => q.id == currentId.value) + 1;

  int get answeredCount => shown.where(isComplete).length;

  int get percent => shown.isEmpty ? 0 : (answeredCount * 100 / shown.length).round();

  void _fillText() {
    dictation.cancel(); // another question: what was being said belonged to the last one
    final q = current;
    final v = q == null ? null : valueOf(q);
    textController.text = v == null ? '' : _plain(v);
    photoNeeded.value = q != null && drafts.containsKey(q.id);
  }

  static String _plain(Object v) => v is double && v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  void _goTo(QuestionOutModel? q) {
    if (q == null) {
      KnToast.success(LangKeys.questionFinished.tr);
      Get.back<bool>(result: true);
      return;
    }
    currentId.value = q.id;
    _fillText();
  }

  Future<void> _next() async {
    await Future<void>.delayed(advanceDelay);
    final list = shown;
    final i = list.indexWhere((q) => q.id == currentId.value);
    _goTo(i >= 0 && i + 1 < list.length ? list[i + 1] : null);
  }

  void onBackTap() {
    final list = shown;
    final i = list.indexWhere((q) => q.id == currentId.value);
    if (i <= 0) {
      Get.back<bool>(result: true);
    } else {
      _goTo(list[i - 1]);
    }
  }

  void onCloseTap() => Get.back<bool>(result: true);

  /// After a photo question's photo: on to the next question.
  Future<void> onNextTap() => _next();

  void onSpeakTap() {
    final q = current;
    if (q == null) return;
    speech.speak([q.text, ?q.help].join('. '), languageCode: translation.currentCode);
  }

  /// Yes/No, Pass/Fail or a choice.
  Future<void> onChoose(Object value) async {
    final q = current;
    if (q == null) return;
    if (locked) return KnToast.info(LangKeys.questionLocked.tr);
    if (needsPhoto(q, value) && !hasPhoto(q)) {
      drafts[q.id] = value;
      photoNeeded.value = true;
      return;
    }
    drafts.remove(q.id);
    photoNeeded.value = false;
    await queue.addAnswer(jobId: args.jobId, checklistId: checklistId, questionId: q.id, value: value);
    await _next();
  }

  /// Number or text: "Next".
  Future<void> onSubmitTyped() async {
    final q = current;
    if (q == null) return;
    final raw = textController.text.trim();
    if (raw.isEmpty) {
      if (!q.requiredValue) await _next();
      return;
    }
    if (q.type == 'number') {
      final n = double.tryParse(raw.replaceAll(',', '.'));
      if (n == null) return KnToast.error(LangKeys.questionNumberHint.tr);
      final lo = q.minValue, hi = q.maxValue;
      if ((lo != null && n < lo) || (hi != null && n > hi)) {
        return KnToast.error(LangKeys.questionRange.trParams({'min': _plain(lo ?? n), 'max': _plain(hi ?? n)}));
      }
      return onChoose(n);
    }
    return onChoose(raw);
  }

  /// Opens the camera for one photo; the answer is sent after the photo.
  Future<void> onTakePhotoTap() async {
    final q = current;
    if (q == null) return;
    if (locked) return KnToast.info(LangKeys.questionLocked.tr);
    final photoId = await Get.toNamed<String>(
      RoutesConstants.cameraScreen,
      arguments: PhotoArguments(jobId: args.jobId, stage: 'during', customer: args.customer, single: true),
    );
    if (photoId == null) return;
    final value = drafts.containsKey(q.id) ? drafts[q.id] : valueOf(q);
    drafts.remove(q.id);
    photoNeeded.value = false;
    await queue.addAnswer(
      jobId: args.jobId,
      checklistId: checklistId,
      questionId: q.id,
      value: value,
      photoRef: photoId,
    );
    await _next();
  }

  /// Signatures go straight to the server (they need internet).
  Future<void> onSignature(Uint8List png) async {
    final q = current;
    if (q == null || saving.value) return;
    saving.value = true;
    final upload = await files.upload(kind: UploadKind.signature, bytes: png, contentType: 'image/png');
    final uploadId = upload.dataOrNull;
    if (uploadId == null) {
      saving.value = false;
      final e = upload.errorOrNull!;
      return KnToast.error(e.isNetwork ? LangKeys.questionSignatureOnline.tr : e.message);
    }
    final result = await checklists.answer(
      checklistId: checklistId,
      questionId: q.id,
      clientUuid: const Uuid().v4(),
      signatureUploadId: uploadId,
    );
    saving.value = false;
    final data = result.dataOrNull;
    if (data == null) return KnToast.error(result.errorOrNull!.message);
    submission.value = data;
    await _next();
  }

  /// "Not sure? Ask your manager": shows the question, takes an optional note (typed or spoken).
  void onNotSureTap() {
    if (current == null) return;
    askNote.clear();
    showAskManagerSheet(this);
  }

  /// Sends the question to the job's managers (they get it in Messages). True when it was sent.
  Future<bool> onAskManager() async {
    final q = current;
    if (q == null || asking.value) return false;
    asking.value = true;
    final result = await jobs.askManager(args.jobId, question: q.text, note: askNote.text);
    asking.value = false;
    final e = result.errorOrNull;
    if (e != null) {
      KnToast.error(e.message);
      return false;
    }
    dictation.cancel();
    KnToast.success(LangKeys.askmgrSent.tr);
    return true;
  }
}
