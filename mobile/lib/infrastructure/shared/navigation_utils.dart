import 'package:get/get.dart';

import '../commons/constants/app_routes.dart';

abstract final class NavigationUtils {
  /// "Back to log in": go back to the email login if it is on the stack, else open it.
  static void backToEmailLogin() {
    var found = false;
    Get.until((route) {
      if (route.settings.name == RoutesConstants.emailLoginScreen) found = true;
      return found || route.isFirst;
    });
    if (!found) Get.toNamed(RoutesConstants.emailLoginScreen);
  }
}
