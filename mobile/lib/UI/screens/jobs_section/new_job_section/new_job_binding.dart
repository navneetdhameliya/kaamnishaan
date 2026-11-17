import 'package:get/get.dart';

import 'new_job_controller.dart';

class NewJobBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => NewJobController(
        jobs: Get.find(),
        customers: Get.find(),
        checklists: Get.find(),
        session: Get.find(),
        translation: Get.find(),
      ),
    );
  }
}
