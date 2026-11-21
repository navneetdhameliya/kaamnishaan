import 'package:get/get.dart';

import 'checklist_builder_controller.dart';

class ChecklistBuilderBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChecklistBuilderController(
          checklists: Get.find(),
          files: Get.find(),
          picker: Get.find(),
          recorder: Get.find(),
          voice: Get.find(),
        ));
  }
}
