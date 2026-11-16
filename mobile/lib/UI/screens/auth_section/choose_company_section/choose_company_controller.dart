import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../common_widgets/kn_toast.dart';

/// Pick which company to work in when the person belongs to more than one.
/// (No Figma screen yet — built from the M02 choice cards; to be designed.)
class ChooseCompanyController extends GetxController {
  ChooseCompanyController({required this.repository, required this.session});

  final IAuthApiRepository repository;
  final SessionService session;

  final RxnString selectedId = RxnString();
  final RxBool apiCallLoader = false.obs;

  @override
  void onInit() {
    super.onInit();
    final companies = session.companies;
    selectedId.value = companies.isEmpty ? null : companies.first.companyId;
  }

  void onCompanyTap(String id) => selectedId.value = id;

  Future<void> callSwitchCompanyAPI() async {
    final id = selectedId.value;
    if (id == null) return;
    apiCallLoader.value = true;
    final result = await repository.switchCompany(id);
    apiCallLoader.value = false;
    final newSession = result.dataOrNull;
    if (newSession == null) return KnToast.error(result.errorOrNull!.message);
    await session.apply(newSession);
    Get.offAllNamed(session.nextRoute());
  }
}
