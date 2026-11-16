import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_toast.dart';

/// M04: technicians with an invite log in by phone; business sign-up arrives in Step 2b.
class WelcomeController extends GetxController {
  void onInviteTap() => Get.toNamed(RoutesConstants.phoneScreen);

  void onLogInTap() => Get.toNamed(RoutesConstants.phoneScreen);

  void onStartBusinessTap() => KnToast.info(LangKeys.welcomeBusinessSoon.tr);
}
