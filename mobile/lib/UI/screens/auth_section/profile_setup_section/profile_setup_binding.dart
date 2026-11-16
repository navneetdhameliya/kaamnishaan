import 'package:get/get.dart';

import 'profile_setup_controller.dart';

class ProfileSetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ProfileSetupController(
        repository: Get.find(),
        session: Get.find(),
        config: Get.find(),
        speech: Get.find(),
        translation: Get.find(),
      ),
    );
  }
}
