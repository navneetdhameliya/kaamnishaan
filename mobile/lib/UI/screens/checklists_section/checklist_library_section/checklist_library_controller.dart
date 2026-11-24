import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/checklists_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/plan_gate.dart';
import '../../../common_widgets/kn_toast.dart';

/// Owners and managers: the company's checklists and KaamNishaan's, and "New checklist" (opens M26).
class ChecklistLibraryController extends GetxController {
  ChecklistLibraryController({required this.checklists});

  final IChecklistsApiRepository checklists;

  final RxList<TemplateListItemModel> items = <TemplateListItemModel>[].obs;
  final RxBool loading = true.obs;
  final RxBool creating = false.obs;
  final TextEditingController name = TextEditingController();
  final RxString nameDraft = ''.obs;

  @override
  void onInit() {
    super.onInit();
    name.addListener(() => nameDraft.value = name.text);
    load();
  }

  @override
  void onClose() {
    name.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final result = await checklists.templates();
    loading.value = false;
    final d = result.dataOrNull;
    if (d == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    // the company's own first, then KaamNishaan's
    items.assignAll([...d.data.where((t) => t.scope == 'company'), ...d.data.where((t) => t.scope != 'company')]);
  }

  /// "12 questions · used in 21 jobs"
  String meta(TemplateListItemModel t) =>
      LangKeys.cbMeta.trParams({'n': '${t.questionCount}', 'm': '${t.usageCount}'});

  /// "By KaamNishaan", "Draft", "Not in new jobs" or nothing.
  String? badge(TemplateListItemModel t) => t.scope != 'company'
      ? LangKeys.cbByKn.tr
      : switch (t.status) {
          'draft' => LangKeys.cbDraft.tr,
          'archived' => LangKeys.cbArchived.tr,
          _ => null,
        };

  Future<void> onOpen(String id) async {
    await Get.toNamed<void>(RoutesConstants.checklistBuilderScreen, arguments: id);
    await load();
  }

  /// "New checklist": your own checklists come with the plan (D-147); false keeps the sheet shut.
  bool startNew() {
    if (!PlanGate.check(PlanFeature.ownChecklists)) return false;
    name.clear();
    return true;
  }

  /// Creates the draft; true when it worked (the sheet closes and the builder opens).
  Future<bool> onCreate() async {
    final n = name.text.trim();
    if (n.isEmpty || creating.value) return false;
    creating.value = true;
    final result = await checklists.create(n);
    creating.value = false;
    final t = result.dataOrNull;
    if (t == null) {
      KnToast.error(result.errorOrNull!.message);
      return false;
    }
    Get.back<void>();
    await onOpen(t.id);
    return true;
  }
}
