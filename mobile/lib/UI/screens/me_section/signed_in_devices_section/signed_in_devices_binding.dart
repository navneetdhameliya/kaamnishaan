import 'package:get/get.dart';

import 'signed_in_devices_controller.dart';

class SignedInDevicesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => SignedInDevicesController(auth: Get.find()));
  }
}
