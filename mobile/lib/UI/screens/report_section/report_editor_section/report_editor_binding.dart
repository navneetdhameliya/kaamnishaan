import 'package:get/get.dart';

import '../../../common_widgets/kn_dictation.dart';
import 'report_editor_controller.dart';

class ReportEditorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReportEditorController(
          reports: Get.find(),
          speech: Get.find(),
          translation: Get.find(),
          dictation: Dictation.find(),
        ));
  }
}
