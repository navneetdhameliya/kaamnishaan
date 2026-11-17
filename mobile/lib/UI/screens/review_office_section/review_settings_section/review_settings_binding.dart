import 'package:get/get.dart';

import 'review_settings_controller.dart';

class ReviewSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReviewSettingsController(reviews: Get.find(), translation: Get.find()));
  }
}
