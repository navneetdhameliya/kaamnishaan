import 'package:get/get.dart';

import 'photo_details_controller.dart';

class PhotoDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PhotoDetailsController(jobs: Get.find(), translation: Get.find()));
  }
}
