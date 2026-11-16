import 'package:get/get.dart';

import 'company_setup_controller.dart';

class CompanySetupBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CompanySetupController(
        companies: Get.find(),
        files: Get.find(),
        session: Get.find(),
        config: Get.find(),
        picker: Get.find(),
        speech: Get.find(),
        translation: Get.find(),
      ),
    );
  }
}
