import 'package:get/get.dart';

import 'report_making_controller.dart';

class ReportMakingBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReportMakingController(reports: Get.find()));
  }
}
