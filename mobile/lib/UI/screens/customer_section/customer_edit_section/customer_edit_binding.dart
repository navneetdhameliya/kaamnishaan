import 'package:get/get.dart';

import 'customer_edit_controller.dart';

class CustomerEditBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CustomerEditController(customers: Get.find()));
  }
}
