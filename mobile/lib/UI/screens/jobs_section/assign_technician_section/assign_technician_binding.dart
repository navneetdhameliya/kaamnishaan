import 'package:get/get.dart';

import 'assign_technician_controller.dart';

class AssignTechnicianBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AssignTechnicianController(jobs: Get.find(), translation: Get.find()));
  }
}
