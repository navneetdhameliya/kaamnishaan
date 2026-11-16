import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../common_widgets/kn_toast.dart';

/// The app after login: bottom tabs and the camera button.
/// Technicians: Today, Me. Owners and managers: Home, Jobs, Reports, Profile.
class HomeShellController extends GetxController {
  HomeShellController({required this.session});

  final SessionService session;

  final RxInt index = 0.obs;

  bool get isManager => const {'owner', 'manager'}.contains(session.me.value?.role);

  void onTabTap(int i) => index.value = i;

  /// The camera (M19 capture) comes with the job screens.
  void onCaptureTap() => KnToast.info(LangKeys.commonComingSoon.tr);

  Future<void> onLogoutTap() async {
    await session.logout();
    Get.offAllNamed(RoutesConstants.welcomeScreen);
  }
}
