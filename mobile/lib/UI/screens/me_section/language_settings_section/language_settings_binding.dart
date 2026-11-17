import 'package:get/get.dart';

import 'language_settings_controller.dart';

class LanguageSettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => LanguageSettingsController(me: Get.find(), session: Get.find(), translation: Get.find()),
    );
  }
}
