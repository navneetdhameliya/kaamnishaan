import 'package:get/get.dart';

import 'help_ticket_controller.dart';

class HelpTicketBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HelpTicketController(repository: Get.find(), translation: Get.find()));
  }
}
