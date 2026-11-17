import 'package:get/get.dart';

import 'billing_controller.dart';

class BillingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => BillingController(billing: Get.find(), translation: Get.find()));
  }
}
