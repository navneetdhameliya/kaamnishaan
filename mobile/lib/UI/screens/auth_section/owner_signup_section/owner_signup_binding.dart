import 'package:get/get.dart';

import 'owner_signup_controller.dart';

class OwnerSignupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => OwnerSignupController(
        repository: Get.find(),
        session: Get.find(),
        speech: Get.find(),
        translation: Get.find(),
      ),
    );
  }
}
