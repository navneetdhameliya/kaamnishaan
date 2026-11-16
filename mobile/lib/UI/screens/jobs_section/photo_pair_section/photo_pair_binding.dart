import 'package:get/get.dart';

import 'photo_pair_controller.dart';

class PhotoPairBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => PhotoPairController(jobs: Get.find(), translation: Get.find()));
  }
}
