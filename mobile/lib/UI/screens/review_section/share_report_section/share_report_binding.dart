import 'package:get/get.dart';

import 'share_report_controller.dart';

class ShareReportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ShareReportController(reports: Get.find()));
  }
}
