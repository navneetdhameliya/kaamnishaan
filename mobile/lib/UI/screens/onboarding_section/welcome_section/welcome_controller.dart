import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';

/// M04: technicians with an invite log in by phone; owners start a business (M07);
/// "Log in" opens the email login (M06), which also offers phone login.
class WelcomeController extends GetxController {
  void onInviteTap() => Get.toNamed(RoutesConstants.phoneScreen);

  void onLogInTap() => Get.toNamed(RoutesConstants.emailLoginScreen);

  void onStartBusinessTap() => Get.toNamed(RoutesConstants.ownerSignupScreen);
}
