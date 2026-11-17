import 'package:get/get.dart';

import '../../../../infrastructure/services/location_service.dart';
import 'camera_controller.dart';

class CameraBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CameraScreenController(camera: Get.find(), queue: Get.find(), jobs: Get.find(), location: Get.find<ILocationService>()),
    );
  }
}
