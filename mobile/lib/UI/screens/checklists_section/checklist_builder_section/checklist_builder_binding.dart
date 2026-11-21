import 'package:get/get.dart';

import '../../../common_widgets/kn_dictation.dart';
import 'checklist_builder_controller.dart';

class ChecklistBuilderBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ChecklistBuilderController(
          checklists: Get.find(),
          files: Get.find(),
          picker: Get.find(),
          dictation: Dictation.find(),
        ));
  }
}
