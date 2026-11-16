import 'package:get/get.dart';

import 'voice_notes_controller.dart';

class VoiceNotesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => VoiceNotesController(voice: Get.find(), queue: Get.find(), player: Get.find()));
  }
}
