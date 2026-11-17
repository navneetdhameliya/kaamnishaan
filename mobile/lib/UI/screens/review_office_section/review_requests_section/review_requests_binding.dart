import 'package:get/get.dart';

import 'review_requests_controller.dart';

class ReviewRequestsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReviewRequestsController(reviews: Get.find(), translation: Get.find()));
  }
}
