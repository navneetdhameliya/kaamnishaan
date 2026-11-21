import 'package:get/get.dart';

import '../../../common_widgets/kn_dictation.dart';
import 'checklist_question_controller.dart';

class ChecklistQuestionBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => ChecklistQuestionController(
        checklists: Get.find(),
        files: Get.find(),
        queue: Get.find(),
        speech: Get.find(),
        translation: Get.find(),
        dictation: Dictation.find(),
      ),
    );
  }
}
