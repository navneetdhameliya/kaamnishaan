import 'package:get/get.dart';

import 'report_review_controller.dart';

class ReportReviewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReportReviewController(reports: Get.find(), jobs: Get.find(), translation: Get.find()));
  }
}
