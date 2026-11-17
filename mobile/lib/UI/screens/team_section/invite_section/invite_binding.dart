import 'package:get/get.dart';

import 'invite_controller.dart';

class InviteBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => InviteController(company: Get.find(), config: Get.find(), session: Get.find(), translation: Get.find()),
    );
  }
}
