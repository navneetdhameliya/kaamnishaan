import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/checklists_api_repository.dart';
import '../../../../infrastructure/data_access_layer/networks/api_result.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../common_widgets/kn_toast.dart';

/// M26 Checklist builder: the questions in order (drag to move), add or change one in a sheet, how many
/// languages are translated, and "Save checklist" (it can then be added to new jobs). A KaamNishaan
/// checklist is read-only until copied.
class ChecklistBuilderController extends GetxController {
  ChecklistBuilderController({required this.checklists, String? templateId})
      : templateId = (templateId ?? Get.arguments as String).obs;

  final IChecklistsApiRepository checklists;
  final RxString templateId;

  static const languages = ['en', 'hi', 'gu', 'es', 'fr'];
  static const types = ['yes_no', 'pass_fail', 'number', 'text', 'photo'];

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

  // ---- the question sheet ------------------------------------------------------------------

  void startAdd() {
    editing.value = null;
    text.clear();
    unit.clear();
    type.value = 'yes_no';
    photo.value = false;
  }

  void startEdit(TemplateQuestionOutModel q) {
    editing.value = q;
    text.text = q.text;
    unit.text = q.unit ?? '';
    type.value = q.type;
    photo.value = q.photoRule != 'none';
  }

  /// The type can't change once the question exists (answers depend on it).
  bool get typeLocked => editing.value != null;

  void onType(String t) {
    if (!typeLocked) type.value = t;
  }

  /// "Photo needed if Fail" — what the photo switch means for this type.
  String get photoLabel => switch (type.value) {
        'yes_no' => LangKeys.cbPhotoIfNo.tr,
        'pass_fail' => LangKeys.cbPhotoIfFail.tr,
        _ => LangKeys.cbPhotoAlways.tr,
      };

  bool get showPhotoSwitch => type.value != 'photo';

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
    final u = unit.text.trim();
    busy.value = true;
    final q = editing.value;
    final result = q == null
        ? await checklists.addQuestion(
            templateId.value,
            QuestionInModel(
              type: type.value,
              text: words,
              photoRule: _photoRule,
              unit: type.value == 'number' && u.isNotEmpty ? u : null,
            ),
          )
        : await checklists.updateQuestion(
            templateId.value,
            q.id,
            QuestionPatchModel(text: words, photoRule: _photoRule, unit: type.value == 'number' && u.isNotEmpty ? u : null),
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

  /// Drag to move: shown at once, then saved.
  Future<void> onReorder(int from, int to) async {
    final t = template.value;
    if (t == null || !editable) return;
    final list = [...t.questions];
    final target = to > from ? to - 1 : to;
    final moved = list.removeAt(from);
    list.insert(target, moved);
    template.value = TemplateOutModel.fromJson({
      ...t.toJson(),
      'questions': [for (final q in list) q.toJson()],
    });
    _take(await checklists.updateQuestion(templateId.value, moved.id, QuestionPatchModel(position: target + 1)));
  }

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
