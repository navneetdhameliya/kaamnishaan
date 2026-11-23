import 'package:get/get.dart';

import '../../../common_widgets/kn_dictation.dart';
import 'quick_job_controller.dart';

class QuickJobBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => QuickJobController(jobs: Get.find(), dictation: Dictation.find()));
  }
}
