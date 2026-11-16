import 'package:get/get.dart';

import 'join_company_controller.dart';

class JoinCompanyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => JoinCompanyController(
        repository: Get.find(),
        session: Get.find(),
        config: Get.find(),
        speech: Get.find(),
        translation: Get.find(),
      ),
    );
  }
}
