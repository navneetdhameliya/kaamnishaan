import 'package:get/get.dart';

import 'review_details_controller.dart';

class ReviewDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReviewDetailsController(reviews: Get.find(), translation: Get.find()));
  }
}
