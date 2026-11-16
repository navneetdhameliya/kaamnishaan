import 'package:get/get.dart';

import 'checklists_controller.dart';

class ChecklistsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChecklistsController(checklists: Get.find(), queue: Get.find(), translation: Get.find()));
  }
}
