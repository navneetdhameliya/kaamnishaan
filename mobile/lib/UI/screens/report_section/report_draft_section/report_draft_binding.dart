import 'package:get/get.dart';

import 'report_draft_controller.dart';

class ReportDraftBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ReportDraftController(
        reports: Get.find(),
        jobs: Get.find(),
        session: Get.find(),
        speech: Get.find(),
        translation: Get.find(),
      ),
    );
  }
}
