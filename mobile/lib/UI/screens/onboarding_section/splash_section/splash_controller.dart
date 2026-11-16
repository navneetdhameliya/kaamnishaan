import 'dart:async';

import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/services/config_service.dart';
import '../../../../infrastructure/services/preferences_service.dart';
import '../../../../infrastructure/services/session_service.dart';

/// M01: shows the brand while the app loads settings and checks for a saved login.
class SplashController extends GetxController {
  SplashController({
    required this.session,
    required this.config,
    required this.prefs,
    required this.translation,
    this.minimumTime = const Duration(milliseconds: 1200),
  });

  final SessionService session;
  final ConfigService config;
  final PreferencesService prefs;
  final TranslationService translation;
  final Duration minimumTime;

  final RxString version = ''.obs;

  @override
  void onReady() {
    super.onReady();
    startApp();
  }

  Future<void> startApp() async {
    unawaited(_loadVersion());
    unawaited(config.load()); // countries and trades; not needed to show the next screen
    final results = await Future.wait([session.restore(), Future<String?>.delayed(minimumTime)]);
    Get.offAllNamed(results.first ?? firstRunRoute());
  }

  /// Where a new (or logged-out) user starts.
  String firstRunRoute() {
    if (!translation.hasChosen) return RoutesConstants.languageScreen;
    if (!prefs.onboardingSeen) return RoutesConstants.introScreen;
    return RoutesConstants.welcomeScreen;
  }

  Future<void> _loadVersion() async {
    try {
      version.value = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      version.value = '';
    }
  }
}
