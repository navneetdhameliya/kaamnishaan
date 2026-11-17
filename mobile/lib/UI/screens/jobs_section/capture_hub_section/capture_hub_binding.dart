import 'package:get/get.dart';

import '../../../../infrastructure/services/location_service.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
import 'capture_hub_controller.dart';

class CaptureHubBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CaptureHubController(
        repository: Get.find(),
        speech: Get.find(),
        translation: Get.find(),
        queue: Get.find<PhotoQueueService>(),
        location: Get.find<ILocationService>(),
      ),
    );
  }
}
