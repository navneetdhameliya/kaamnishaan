import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/checklists_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import '../../../../infrastructure/data_access_layer/networks/api_result.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/image_picker_service.dart';
import '../../../common_widgets/kn_toast.dart';

/// One choice in a "Choice" question: its saved key (null until saved) and its words.
class OptionDraft {
  OptionDraft({this.key, String label = ''}) : text = TextEditingController(text: label);

  final String? key;
  final TextEditingController text;
}

/// M26 Checklist builder: the questions in order (drag to move), add or change one in a sheet, how many
/// languages are translated, and "Save checklist" (it can then be added to new jobs). A KaamNishaan
/// checklist is read-only until copied. Preview shows it the way a technician answers it.
class ChecklistBuilderController extends GetxController {
  ChecklistBuilderController({required this.checklists, required this.files, required this.picker, String? templateId})
      : templateId = (templateId ?? Get.arguments as String).obs;

  final IChecklistsApiRepository checklists;
  final IFilesApiRepository files;
  final IImagePickerService picker;
  final RxString templateId;

  static const languages = ['en', 'hi', 'gu', 'es', 'fr'];
  static const types = ['yes_no', 'pass_fail', 'choice', 'number', 'text', 'photo'];

  /// Questions whose answer can decide whether a later one is shown.
  static const ruleTypes = ['yes_no', 'pass_fail', 'choice'];
  static const maxOptions = 12;

  final Rxn<TemplateOutModel> template = Rxn<TemplateOutModel>();
  final RxBool busy = false.obs;

  // the question sheet
  final Rxn<TemplateQuestionOutModel> editing = Rxn<TemplateQuestionOutModel>();
  final TextEditingController text = TextEditingController();
  final TextEditingController unit = TextEditingController();
  final TextEditingController rename = TextEditingController();
  final RxString textDraft = ''.obs;
  final RxString type = 'yes_no'.obs;
  final RxBool photo = false.obs;

  /// The reference photo (what a good answer looks like): the one saved, a new one picked, or taken off.
  final RxnString referenceUrl = RxnString();
  final Rxn<PickedImage> referencePicked = Rxn<PickedImage>();

  /// "Choice" answers, whether an answer is needed, and "Show only if".
  final RxList<OptionDraft> options = <OptionDraft>[].obs;
  final RxBool requiredAnswer = true.obs;
  final RxnString ruleQuestionId = RxnString();
  final RxnString ruleEquals = RxnString();

  /// Preview: the answers tapped so far (question id → answer key), to show the "show only if" questions.
  final RxMap<String, String> previewAnswers = <String, String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    text.addListener(() => textDraft.value = text.text);
    load();
  }

  @override
  void onClose() {
    text.dispose();
    unit.dispose();
    rename.dispose();
    _clearOptions();
    super.onClose();
  }

  Future<void> load() async {
    final result = await checklists.template(templateId.value);
    _take(result);
  }

  bool _take(ApiResult<TemplateOutModel> result) {
    final t = result.dataOrNull;
    if (t == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return false;
    }
    template.value = t;
    templateId.value = t.id;
    return true;
  }

  // ---- what it shows -----------------------------------------------------------------------

  String get name => template.value?.name ?? '';

  bool get editable => template.value?.editable ?? false;

  bool get draft => template.value?.status == 'draft';

  bool get archived => template.value?.status == 'archived';

  List<TemplateQuestionOutModel> get questions => template.value?.questions ?? const [];

  /// "12 questions · used in 21 jobs"
  String get subtitle {
    final t = template.value;
    return t == null ? '' : LangKeys.cbMeta.trParams({'n': '${t.questionCount}', 'm': '${t.usageCount}'});
  }

  /// Languages every question is ready in.
  int get languagesReady {
    final qs = questions;
    if (qs.isEmpty) return languages.length;
    return languages.where((l) => qs.every((q) => q.textStatus[l] == 'ready')).length;
  }

  String get translations => LangKeys.cbTrReady.trParams({'n': '$languagesReady'});

  static String typeLabel(String type) => switch (type) {
        'yes_no' => LangKeys.cbTYesNo.tr,
        'pass_fail' => LangKeys.cbTPassFail.tr,
        'number' => LangKeys.cbTNumber.tr,
        'photo' => LangKeys.cbTPhoto.tr,
        'choice' => LangKeys.cbTChoice.tr,
        'signature' => LangKeys.cbTSignature.tr,
        _ => LangKeys.cbTText.tr,
      };

  /// "Pass / Fail · photo"
  String chip(TemplateQuestionOutModel q) => q.photoRule == 'none' || q.type == 'photo'
      ? typeLabel(q.type)
      : LangKeys.cbWithPhoto.trParams({'type': typeLabel(q.type)});

  /// The words of an answer key: "Yes", "Fail", or the choice's own words.
  static String answerLabel(TemplateQuestionOutModel q, String key) => switch (key) {
        'yes' when q.type == 'yes_no' => LangKeys.questionYes.tr,
        'no' when q.type == 'yes_no' => LangKeys.questionNo.tr,
        'pass' when q.type == 'pass_fail' => LangKeys.questionPass.tr,
        'fail' when q.type == 'pass_fail' => LangKeys.questionFail.tr,
        _ => q.options.firstWhereOrNull((o) => o.key == key)?.label ?? key,
      };

  /// The answers a "show only if" rule can wait for: (key, words).
  static List<(String, String)> answers(TemplateQuestionOutModel q) => switch (q.type) {
        'yes_no' => [('yes', LangKeys.questionYes.tr), ('no', LangKeys.questionNo.tr)],
        'pass_fail' => [('pass', LangKeys.questionPass.tr), ('fail', LangKeys.questionFail.tr)],
        _ => [for (final o in q.options) (o.key, o.label)],
      };

  /// "Only if Q2 is Fail · optional" under a question in the list; null when neither applies.
  String? note(TemplateQuestionOutModel q) {
    final parts = <String>[];
    final c = q.condition;
    if (c != null) {
      final i = questions.indexWhere((x) => x.id == c['question_id']);
      if (i >= 0) {
        parts.add(LangKeys.cbRuleNote.trParams({'n': '${i + 1}', 'answer': answerLabel(questions[i], '${c['equals']}')}));
      }
    }
    if (!q.requiredValue) parts.add(LangKeys.cbOptional.tr);
    return parts.isEmpty ? null : parts.join(' · ');
  }

  // ---- the question sheet ------------------------------------------------------------------

  void startAdd() {
    editing.value = null;
    text.clear();
    unit.clear();
    type.value = 'yes_no';
    photo.value = false;
    referenceUrl.value = null;
    referencePicked.value = null;
    _clearOptions();
    requiredAnswer.value = true;
    ruleQuestionId.value = null;
    ruleEquals.value = null;
  }

  void startEdit(TemplateQuestionOutModel q) {
    editing.value = q;
    text.text = q.text;
    unit.text = q.unit ?? '';
    type.value = q.type;
    photo.value = q.photoRule != 'none';
    referenceUrl.value = q.referenceImageUrl;
    referencePicked.value = null;
    _clearOptions();
    options.addAll([for (final o in q.options) OptionDraft(key: o.key, label: o.label)]);
    requiredAnswer.value = q.requiredValue;
    ruleQuestionId.value = q.condition?['question_id'] as String?;
    ruleEquals.value = q.condition == null ? null : '${q.condition!['equals']}';
  }

  void _clearOptions() {
    for (final o in options) {
      o.text.dispose();
    }
    options.clear();
  }

  // ---- choice answers ----------------------------------------------------------------------

  bool get canAddOption => options.length < maxOptions;

  bool get canRemoveOption => options.length > 2;

  void onAddOption() {
    if (canAddOption) options.add(OptionDraft());
  }

  void onRemoveOption(int i) {
    if (!canRemoveOption) return;
    options.removeAt(i).text.dispose();
  }

  List<OptionInModel> get _filledOptions => [
        for (final o in options)
          if (o.text.text.trim().isNotEmpty) OptionInModel(key: o.key, label: o.text.text.trim()),
      ];

  // ---- show only if ------------------------------------------------------------------------

  /// Earlier Yes/No, Pass/Fail or Choice questions this one can wait for.
  List<TemplateQuestionOutModel> get ruleSources {
    final q = editing.value;
    final before = q == null ? questions : questions.where((x) => x.position < q.position);
    return [for (final x in before) if (ruleTypes.contains(x.type)) x];
  }

  TemplateQuestionOutModel? get ruleSource => ruleSources.firstWhereOrNull((x) => x.id == ruleQuestionId.value);

  /// Picks the question to wait for (null: always show); its first answer is chosen to start with.
  void onRuleQuestion(String? id) {
    ruleQuestionId.value = id;
    final src = ruleSource;
    ruleEquals.value = src == null ? null : answers(src).first.$1;
  }

  void onRuleAnswer(String key) => ruleEquals.value = key;

  ConditionInModel? get _rule {
    final src = ruleSource;
    final eq = ruleEquals.value;
    return src == null || eq == null ? null : ConditionInModel(questionId: src.id, equals: eq);
  }

  bool get hasReference => referencePicked.value != null || referenceUrl.value != null;

  /// Takes or chooses the reference photo; it is uploaded when the question is saved.
  Future<void> onPickReference(PickSource source) async {
    final picked = await picker.pick(source, maxSide: 1600);
    if (picked != null) referencePicked.value = picked;
  }

  void onRemoveReference() {
    referencePicked.value = null;
    referenceUrl.value = null;
  }

  /// Whether saving takes the saved reference photo off.
  bool get _referenceRemoved => editing.value?.referenceImageUrl != null && !hasReference;

  /// The type can't change once the question exists (answers depend on it).
  bool get typeLocked => editing.value != null;

  void onType(String t) {
    if (typeLocked) return;
    type.value = t;
    if (t == 'choice' && options.isEmpty) options.addAll([OptionDraft(), OptionDraft()]);
  }

  /// "Photo needed if Fail" — what the photo switch means for this type.
  String get photoLabel => switch (type.value) {
        'yes_no' => LangKeys.cbPhotoIfNo.tr,
        'pass_fail' => LangKeys.cbPhotoIfFail.tr,
        _ => LangKeys.cbPhotoAlways.tr,
      };

  bool get showPhotoSwitch => type.value != 'photo' && type.value != 'signature';

  String get _photoRule {
    if (type.value == 'photo') return 'always';
    if (!photo.value) return 'none';
    return switch (type.value) {
      'yes_no' => 'if_no',
      'pass_fail' => 'if_fail',
      _ => 'always',
    };
  }

  /// Adds or saves the question; true when it worked (the sheet closes).
  Future<bool> onSaveQuestion() async {
    final words = text.text.trim();
    if (words.isEmpty || busy.value) return false;
    final choice = type.value == 'choice';
    final opts = choice ? _filledOptions : null;
    if (opts != null && opts.length < 2) {
      KnToast.info(LangKeys.cbOptionsNeeded.tr);
      return false;
    }
    final u = unit.text.trim();
    busy.value = true;
    String? referenceUploadId;
    final picked = referencePicked.value;
    if (picked != null) {
      final upload = await files.upload(kind: UploadKind.photo, bytes: picked.bytes, contentType: picked.contentType);
      referenceUploadId = upload.dataOrNull;
      if (referenceUploadId == null) {
        busy.value = false;
        KnToast.error(LangKeys.cbRefFailed.tr);
        return false;
      }
    }
    final q = editing.value;
    final result = q == null
        ? await checklists.addQuestion(
            templateId.value,
            QuestionInModel(
              type: type.value,
              text: words,
              photoRule: _photoRule,
              unit: type.value == 'number' && u.isNotEmpty ? u : null,
              referenceUploadId: referenceUploadId,
              options: opts,
              requiredValue: requiredAnswer.value,
              condition: _rule,
            ),
          )
        : await checklists.updateQuestion(
            templateId.value,
            q.id,
            QuestionPatchModel(
              text: words,
              photoRule: _photoRule,
              unit: type.value == 'number' && u.isNotEmpty ? u : null,
              referenceUploadId: referenceUploadId,
              removeReference: _referenceRemoved ? true : null,
              options: opts,
              requiredValue: requiredAnswer.value,
              condition: _rule,
              clearCondition: _rule == null && q.condition != null ? true : null,
            ),
          );
    busy.value = false;
    return _take(result);
  }

  Future<bool> onDeleteQuestion() async {
    final q = editing.value;
    if (q == null || busy.value) return false;
    busy.value = true;
    final result = await checklists.deleteQuestion(templateId.value, q.id);
    busy.value = false;
    if (result.errorOrNull != null) {
      KnToast.error(result.errorOrNull!.message);
      return false;
    }
    KnToast.success(LangKeys.cbDeleted.tr);
    await load();
    return true;
  }

  /// Drag to move: shown at once, then saved. [to] is the question's new place in the list.
  Future<void> onReorder(int from, int to) async {
    final t = template.value;
    if (t == null || !editable) return;
    final list = [...t.questions];
    final target = to;
    final moved = list.removeAt(from);
    list.insert(target, moved);
    template.value = TemplateOutModel.fromJson({
      ...t.toJson(),
      'questions': [for (final q in list) q.toJson()],
    });
    _take(await checklists.updateQuestion(templateId.value, moved.id, QuestionPatchModel(position: target + 1)));
  }

  // ---- preview -----------------------------------------------------------------------------

  void startPreview() => previewAnswers.clear();

  /// Shown in the preview: no rule, or the question it waits for is shown and has that answer.
  bool previewShown(TemplateQuestionOutModel q, [int depth = 0]) {
    final c = q.condition;
    if (c == null) return true;
    final src = questions.firstWhereOrNull((x) => x.id == c['question_id']);
    if (src == null || depth > questions.length) return true;
    return previewShown(src, depth + 1) && previewAnswers[src.id] == '${c['equals']}';
  }

  List<TemplateQuestionOutModel> get previewQuestions => [for (final q in questions) if (previewShown(q)) q];

  /// Taps an answer in the preview; tapping it again clears it.
  void onPreviewAnswer(TemplateQuestionOutModel q, String key) {
    if (previewAnswers[q.id] == key) {
      previewAnswers.remove(q.id);
    } else {
      previewAnswers[q.id] = key;
    }
  }

  /// "8 of 9 questions shown"
  String get previewCount =>
      LangKeys.cbPreviewCount.trParams({'n': '${previewQuestions.length}', 'm': '${questions.length}'});

  // ---- the checklist -----------------------------------------------------------------------

  /// "Save checklist": it can be added to new jobs.
  Future<void> onSave() async {
    if (questions.isEmpty) return KnToast.info(LangKeys.cbEmptyBody.tr);
    busy.value = true;
    final ok = _take(await checklists.update(templateId.value, status: 'published'));
    busy.value = false;
    if (ok) KnToast.success(LangKeys.cbSaved.tr);
  }

  /// A KaamNishaan checklist: copy it, then the copy opens here.
  Future<void> onCopy() async {
    busy.value = true;
    final ok = _take(await checklists.copy(templateId.value));
    busy.value = false;
    if (ok) KnToast.success(LangKeys.cbCopied.tr);
  }

  void startRename() => rename.text = name;

  Future<bool> onRename() async {
    final n = rename.text.trim();
    if (n.isEmpty || n == name) return n.isNotEmpty;
    return _take(await checklists.update(templateId.value, name: n));
  }

  Future<void> onArchiveTap() async {
    final ok = _take(await checklists.update(templateId.value, status: archived ? 'published' : 'archived'));
    if (ok && archived) KnToast.info(LangKeys.cbArchivedToast.tr);
  }
}
