import 'package:get/get.dart';

import 'waiting_to_send_controller.dart';

class WaitingToSendBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => WaitingToSendController(queue: Get.find(), translation: Get.find()));
  }
}
