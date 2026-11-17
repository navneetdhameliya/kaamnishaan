import 'package:get/get.dart';

import 'review_followup_controller.dart';

class ReviewFollowupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReviewFollowupController(reviews: Get.find()));
  }
}
