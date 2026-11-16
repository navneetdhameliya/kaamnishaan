import 'package:get/get.dart';

import 'job_details_controller.dart';

class JobDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => JobDetailsController(
        repository: Get.find(),
        session: Get.find(),
        speech: Get.find(),
        translation: Get.find(),
      ),
    );
  }
}
