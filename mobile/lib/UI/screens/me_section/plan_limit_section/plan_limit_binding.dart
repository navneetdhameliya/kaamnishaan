import 'package:get/get.dart';

import 'plan_limit_controller.dart';

class PlanLimitBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PlanLimitController(billing: Get.find(), translation: Get.find()));
  }
}
