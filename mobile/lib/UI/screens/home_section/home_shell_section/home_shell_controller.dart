import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_toast.dart';

/// The app after login: bottom tabs and the camera button.
/// Technicians: Today, Me. Owners and managers: Home, Jobs, Reports, Profile.
class HomeShellController extends GetxController {
  HomeShellController({required this.session});

  final SessionService session;

  final RxInt index = 0.obs;

  bool get isManager => const {'owner', 'manager'}.contains(session.me.value?.role);

  void onTabTap(int i) => index.value = i;

  /// The camera button: a technician goes to the proof of the job in progress (M19).
  void onCaptureTap() {
    final current = currentJob?.call();
    if (current != null) {
      Get.toNamed(RoutesConstants.captureHubScreen, arguments: JobArguments.of(current));
    } else {
      KnToast.info(LangKeys.commonComingSoon.tr);
    }
  }

  /// Set by the shell binding: the technician's job in progress, from Today.
  JobListItemModel? Function()? currentJob;

  Future<void> onLogoutTap() async {
    await session.logout();
    Get.offAllNamed(RoutesConstants.welcomeScreen);
  }
}
