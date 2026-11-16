import 'package:get/get.dart';

import 'job_list_controller.dart';

class JobListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => JobListController(repository: Get.find(), session: Get.find(), translation: Get.find()));
  }
}
