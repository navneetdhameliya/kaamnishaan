import 'package:get/get.dart';

import 'my_reviews_controller.dart';

class MyReviewsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => MyReviewsController(reviews: Get.find()));
  }
}
