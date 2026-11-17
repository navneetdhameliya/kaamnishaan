import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/reviews_api_repository.dart';
import '../../../../infrastructure/services/location_service.dart';
import 'job_details_controller.dart';

class JobDetailsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => JobDetailsController(
        repository: Get.find(),
        session: Get.find(),
        speech: Get.find(),
        translation: Get.find(),
        location: Get.find<ILocationService>(),
        reviews: Get.find<IReviewsApiRepository>(),
      ),
    );
  }
}
