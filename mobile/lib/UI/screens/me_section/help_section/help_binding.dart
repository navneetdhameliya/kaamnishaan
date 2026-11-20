import 'package:get/get.dart';

import 'help_controller.dart';

class HelpBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HelpController(repository: Get.find(), translation: Get.find()));
  }
}
