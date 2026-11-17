import 'package:get/get.dart';

import 'credits_controller.dart';

class CreditsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CreditsController(billing: Get.find(), translation: Get.find()));
  }
}
