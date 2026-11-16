import 'package:get/get.dart';

import 'otp_controller.dart';

class OtpBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => OtpController(
        repository: Get.find(),
        session: Get.find(),
        prefs: Get.find(),
        speech: Get.find(),
        translation: Get.find(),
        args: Get.arguments as OtpArguments,
      ),
    );
  }
}
