import 'package:get/get.dart';

import 'voice_note_controller.dart';

class VoiceNoteBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => VoiceNoteController(voice: Get.find(), player: Get.find()));
  }
}
