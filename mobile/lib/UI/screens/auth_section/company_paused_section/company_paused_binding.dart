import 'package:get/get.dart';

import 'company_paused_controller.dart';

class CompanyPausedBinding extends Bindings {
  @override
  void dependencies() => Get.lazyPut(() => CompanyPausedController(session: Get.find()));
}
