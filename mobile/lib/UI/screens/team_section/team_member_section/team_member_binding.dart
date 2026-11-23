import 'package:get/get.dart';

import 'team_member_controller.dart';

class TeamMemberBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => TeamMemberController(company: Get.find(), session: Get.find()));
  }
}
