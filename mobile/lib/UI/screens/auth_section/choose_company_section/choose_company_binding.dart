import 'package:get/get.dart';

import 'choose_company_controller.dart';

class ChooseCompanyBinding extends Bindings {
  @override
  void dependencies() =>
      Get.lazyPut(() => ChooseCompanyController(repository: Get.find(), session: Get.find()));
}
