import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reviews_api_repository.dart';
import 'report_sent_controller.dart';

class ReportSentBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => ReportSentController(reports: Get.find(), translation: Get.find(), jobs: Get.find<IJobsApiRepository>(), reviews: Get.find<IReviewsApiRepository>()));
  }
}
