import 'package:get/get.dart';

import '../../../common_widgets/kn_dictation.dart';
import 'company_reviews_controller.dart';

class CompanyReviewsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CompanyReviewsController(reviews: Get.find(), dictation: Dictation.find()));
  }
}
