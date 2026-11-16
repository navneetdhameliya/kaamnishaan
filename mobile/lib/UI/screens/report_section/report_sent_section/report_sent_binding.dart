import 'package:get/get.dart';

import 'report_sent_controller.dart';

class ReportSentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReportSentController(reports: Get.find(), translation: Get.find()));
  }
}
