import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/reports_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/speech_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_dictation.dart';
import '../../../common_widgets/kn_toast.dart';

/// One part of the report the technician can change.
class ReportPart {
  ReportPart(this.key, this.titleKey, {required this.required});

  /// "summary", "work_done", "advice" (as the server names them).
  final String key;
  final String titleKey;

  /// Translated when shown, so it follows the app's language.
  String get title => titleKey.tr;
  final bool required;
  final TextEditingController text = TextEditingController();
  final FocusNode focus = FocusNode();
  final RxBool empty = false.obs;
  final RxBool rewriting = false.obs;
  String original = '';

  bool get changed => text.text.trim() != original.trim();

  void dispose() {
    text.dispose();
    focus.dispose();
  }
}

/// M32 Report editor: the words only. Photos and checklist answers are proof and cannot be changed here.
/// Each part can be typed, spoken (the microphone writes it in), or written again by AI.
class ReportEditorController extends GetxController {
  ReportEditorController({
    required this.reports,
    required this.speech,
    required this.translation,
    required this.dictation,
    ReportArguments? args,
    this.pollEvery = const Duration(milliseconds: 1200),
  }) : args = args ?? Get.arguments as ReportArguments;

  final IReportsApiRepository reports;
  final ISpeechService speech;
  final TranslationService translation;

  /// Speak instead of typing a part.
  final Dictation dictation;
  final ReportArguments args;
  final Duration pollEvery;

  late final List<ReportPart> parts = [
    ReportPart('summary', LangKeys.reportSummary, required: true),
    ReportPart('work_done', LangKeys.reportWorkDone, required: true),
    ReportPart('advice', LangKeys.reportAdvice, required: false),
  ];

  final Rxn<ReportOutModel> report = Rxn<ReportOutModel>();
  final RxBool saving = false.obs;

  /// Bumped on every keystroke so the Save button follows.
  final RxInt edits = 0.obs;

  String get reportId => args.reportId!;

  @override
  void onInit() {
    super.onInit();
    for (final p in parts) {
      p.text.addListener(() {
        if (p.required) p.empty.value = p.text.text.trim().isEmpty;
        edits.value++;
      });
    }
    load();
  }

  @override
  void onClose() {
    speech.stop();
    dictation.cancel();
    for (final p in parts) {
      p.dispose();
    }
    super.onClose();
  }

  Future<void> load() async {
    final result = await reports.report(reportId);
    final r = result.dataOrNull;
    if (r == null) return KnToast.error(result.errorOrNull!.message);
    report.value = r;
    for (final p in parts) {
      _fill(p, r);
    }
  }

  void _fill(ReportPart p, ReportOutModel r) {
    final value = switch (p.key) { 'summary' => r.summary, 'work_done' => r.workDone, _ => r.advice } ?? '';
    p
      ..original = value
      ..text.text = value;
  }

  bool get loaded => report.value != null;

  bool get canRewrite => report.value?.actions.contains('regenerate') ?? false;

  bool get hasChanges {
    edits.value; // follow typing
    return parts.any((p) => p.changed);
  }

  bool get valid {
    edits.value;
    return parts.every((p) => !p.required || p.text.text.trim().isNotEmpty);
  }

  bool get canSave => loaded && valid && hasChanges && !saving.value;

  /// Who wrote this part: "ai", "template" or "technician".
  String sourceOf(ReportPart p) => '${report.value?.sectionSources[p.key] ?? ''}';

  String emptyText(ReportPart p) => LangKeys.editorEmpty.trParams({'part': p.title});

  /// "Hear it": reads the message out loud.
  Future<void> onHearTap(ReportPart p) => speech.speak(emptyText(p), languageCode: translation.currentCode);

  /// After the person agreed: the AI writes this part again; the other parts keep the person's words.
  Future<void> rewrite(ReportPart p) async {
    p.rewriting.value = true;
    final started = await reports.regenerate(reportId, p.key);
    final s = started.dataOrNull;
    if (s == null) {
      p.rewriting.value = false;
      return KnToast.error(started.errorOrNull!.message);
    }
    while (true) {
      await Future<void>.delayed(pollEvery);
      final task = (await reports.task(s.taskId)).dataOrNull;
      if (task == null || task.status == 'queued' || task.status == 'running') continue;
      if (task.status == 'failed') {
        p.rewriting.value = false;
        return KnToast.error(task.error ?? LangKeys.reportFailedTitle.tr);
      }
      break;
    }
    final r = (await reports.report(reportId)).dataOrNull;
    p.rewriting.value = false;
    if (r == null) return;
    report.value = r;
    _fill(p, r);
    KnToast.success(LangKeys.editorAiDone.tr);
  }

  Future<void> onSaveTap() async {
    if (!canSave) return;
    String? part(String key) {
      final p = parts.firstWhere((p) => p.key == key);
      return p.changed ? p.text.text.trim() : null;
    }

    saving.value = true;
    final result = await reports.edit(
      reportId,
      summary: part('summary'),
      workDone: part('work_done'),
      advice: part('advice'),
    );
    saving.value = false;
    final r = result.dataOrNull;
    if (r == null) {
      final e = result.errorOrNull!;
      for (final key in e.fields.keys) {
        parts.firstWhereOrNull((p) => p.key == key)?.empty.value = true;
      }
      return KnToast.error(e.message);
    }
    report.value = r;
    KnToast.success(LangKeys.editorSaved.tr);
    Get.back<bool>(result: true);
  }
}
