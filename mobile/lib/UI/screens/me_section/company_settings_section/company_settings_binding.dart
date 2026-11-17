import 'package:get/get.dart';

import 'company_settings_controller.dart';

class CompanySettingsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CompanySettingsController(
        companies: Get.find(),
        files: Get.find(),
        session: Get.find(),
        config: Get.find(),
        picker: Get.find(),
        translation: Get.find(),
      ),
    );
  }
}
