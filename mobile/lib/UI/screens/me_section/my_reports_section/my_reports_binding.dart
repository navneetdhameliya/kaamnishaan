import 'package:get/get.dart';

import 'my_reports_controller.dart';

class MyReportsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MyReportsController(me: Get.find(), translation: Get.find()));
  }
}
