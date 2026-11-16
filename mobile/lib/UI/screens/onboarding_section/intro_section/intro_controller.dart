import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/services/preferences_service.dart';

/// M03: three intro slides, shown once.
class IntroController extends GetxController {
  IntroController({required this.prefs});

  final PreferencesService prefs;
  static const pageCount = 3;

  final PageController pageController = PageController();
  final RxInt page = 0.obs;

  bool get isLast => page.value == pageCount - 1;

  void onPageChanged(int index) => page.value = index;

  Future<void> onNextTap() async {
    if (isLast) return finish();
    await pageController.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  Future<void> finish() async {
    await prefs.setOnboardingSeen();
    Get.offAllNamed(RoutesConstants.welcomeScreen);
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
