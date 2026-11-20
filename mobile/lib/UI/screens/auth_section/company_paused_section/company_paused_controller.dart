import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/services/session_service.dart';

/// Shown when KaamNishaan has paused (suspended) the company this person works in (admin A07).
/// The server refuses the company's work until it is turned back on; nothing is deleted.
class CompanyPausedController extends GetxController {
  CompanyPausedController({required this.session});

  final SessionService session;
  final RxBool apiCallLoader = false.obs;

  String get companyName => session.me.value?.company?.name ?? '';

  /// Another company to work in, when the person belongs to more than one.
  bool get canSwitch => session.companies.length > 1;

  /// Asks the server again: if the company was turned back on, the app opens as usual.
  Future<void> callRefreshAPI() async {
    apiCallLoader.value = true;
    final next = await session.refreshAndRoute();
    apiCallLoader.value = false;
    if (next != RoutesConstants.companyPausedScreen) Get.offAllNamed<void>(next);
  }

  void onSwitchTap() => Get.offAllNamed<void>(RoutesConstants.chooseCompanyScreen);

  Future<void> onLogoutTap() async {
    await session.logout();
    Get.offAllNamed<void>(RoutesConstants.welcomeScreen);
  }
}
