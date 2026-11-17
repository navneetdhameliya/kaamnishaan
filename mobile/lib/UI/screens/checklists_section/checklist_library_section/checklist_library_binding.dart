import 'package:get/get.dart';

import 'checklist_library_controller.dart';

class ChecklistLibraryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChecklistLibraryController(checklists: Get.find()));
  }
}
