import 'package:get/get.dart';

import 'capture_hub_controller.dart';

class CaptureHubBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CaptureHubController(repository: Get.find(), speech: Get.find(), translation: Get.find()));
  }
}
