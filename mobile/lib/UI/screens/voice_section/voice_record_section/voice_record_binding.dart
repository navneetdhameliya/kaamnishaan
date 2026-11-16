import 'package:get/get.dart';

import 'voice_record_controller.dart';

class VoiceRecordBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => VoiceRecordController(recorder: Get.find(), queue: Get.find()));
  }
}
