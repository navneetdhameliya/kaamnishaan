import 'package:get/get.dart';

import 'help_new_controller.dart';

class HelpNewBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HelpNewController(repository: Get.find()));
  }
}
