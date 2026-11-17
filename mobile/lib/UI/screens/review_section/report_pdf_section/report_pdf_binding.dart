import 'package:get/get.dart';

import 'report_pdf_controller.dart';

class ReportPdfBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ReportPdfController(reports: Get.find(), jobs: Get.find(), session: Get.find(), translation: Get.find()),
    );
  }
}
