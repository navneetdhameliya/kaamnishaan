import 'package:get/get.dart';

import 'forgot_password_controller.dart';

class ForgotPasswordBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ForgotPasswordController(repository: Get.find(), speech: Get.find(), translation: Get.find()),
    );
  }
}
