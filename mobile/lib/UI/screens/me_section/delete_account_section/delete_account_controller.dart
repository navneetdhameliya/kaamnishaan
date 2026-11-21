import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/me_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../common_widgets/kn_toast.dart';

/// Me → Delete account (D-130): what happens, an owner picks a new owner first, then delete for good.
class DeleteAccountController extends GetxController {
  DeleteAccountController({required this.repository, required this.session});

  final IMeApiRepository repository;
  final SessionService session;

  final Rxn<DeletionCheckModel> check = Rxn<DeletionCheckModel>();
  final RxBool loading = true.obs;
  final RxnString loadError = RxnString();
  final RxMap<String, String> newOwner = <String, String>{}.obs; // company id -> picked person
  final RxnString handing = RxnString(); // company being handed over
  final RxBool understood = false.obs;
  final RxBool deleting = false.obs;
  final RxnString error = RxnString();
  final reason = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    reason.dispose();
    super.onClose();
  }

  Future<void> load() async {
    loading.value = true;
    loadError.value = null;
    final r = await repository.deletionCheck();
    loading.value = false;
    final c = r.dataOrNull;
    if (c == null) {
      loadError.value = r.errorOrNull?.message ?? LangKeys.delErrGeneric.tr;
      return;
    }
    check.value = c;
  }

  String? get currentCompanyId => session.me.value?.company?.id;

  /// Owners can only hand over the company they are working in now.
  bool canHandOver(DeletionCompanyModel c) => c.companyId == currentCompanyId;

  String roleLabel(String role) => switch (role) {
        'owner' => LangKeys.roleOwner.tr,
        'manager' => LangKeys.roleManager.tr,
        _ => LangKeys.roleTechnician.tr,
      };

  bool get ready => (check.value?.canDelete ?? false) && understood.value && !deleting.value;

  Future<void> onHandOver(DeletionCompanyModel c) async {
    final picked = newOwner[c.companyId];
    if (picked == null || handing.value != null) return;
    handing.value = c.companyId;
    error.value = null;
    final r = await repository.changeOwner(picked);
    handing.value = null;
    final me = r.dataOrNull;
    if (me == null) {
      error.value = r.errorOrNull?.message ?? LangKeys.delErrGeneric.tr;
      return;
    }
    session.me.value = me;
    KnToast.success(LangKeys.delOwnerDone.trParams({'company': c.name}));
    await load();
  }

  void onDisabledTap() {
    error.value = (check.value?.canDelete ?? false) ? LangKeys.delErrConfirm.tr : LangKeys.delErrOwner.tr;
  }

  Future<void> onDelete() async {
    if (!ready) {
      onDisabledTap();
      return;
    }
    deleting.value = true;
    error.value = null;
    final text = reason.text.trim();
    final r = await repository.deleteAccount(reason: text.isEmpty ? null : text);
    if (r.errorOrNull != null) {
      deleting.value = false;
      error.value = r.errorOrNull!.message;
      if (r.errorOrNull!.code == 'owner_has_team') await load();
      return;
    }
    // the server has already ended every session; forget this one here too
    await session.clear();
    KnToast.success(LangKeys.delDone.tr);
    await Get.offAllNamed<void>(RoutesConstants.welcomeScreen);
  }
}
