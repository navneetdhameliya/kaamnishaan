import 'dart:async';

import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/services/config_service.dart';
import '../../../../infrastructure/services/preferences_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/app_logger.dart';

/// M01: shows the brand while the app loads settings and checks for a saved login.
class SplashController extends GetxController {
  SplashController({
    required this.session,
    required this.config,
    required this.prefs,
    required this.translation,
    this.minimumTime = const Duration(milliseconds: 1200),
    this.restoreLimit = const Duration(seconds: 20),
  });

  final SessionService session;
  final ConfigService config;
  final PreferencesService prefs;
  final TranslationService translation;
  final Duration minimumTime;

  /// The free test server can take about a minute to wake up; after this the app goes on and the next
  /// screen loads its own data (a saved login goes home, and Home retries).
  final Duration restoreLimit;

  final RxString version = ''.obs;

  @override
  void onReady() {
    super.onReady();
    startApp();
  }

  Future<void> startApp() async {
    unawaited(_loadVersion());
    unawaited(config.load()); // countries and trades; not needed to show the next screen
    final results = await Future.wait([nextRoute(), Future<String?>.delayed(minimumTime)]);
    Get.offAllNamed(results.first ?? firstRunRoute());
  }

  /// The screen after a saved login is checked; never waits longer than [restoreLimit] and never fails.
  Future<String?> nextRoute() async {
    try {
      return await session.restore().timeout(restoreLimit, onTimeout: _whileServerWakes);
    } catch (e) {
      AppLogger.error('Saved login could not be checked', error: e);
      return _whileServerWakes();
    }
  }

  /// A saved login goes home (it keeps working offline); otherwise the first-run screens.
  Future<String?> _whileServerWakes() async {
    try {
      return await session.tokens.readRefresh() == null ? null : RoutesConstants.homeScreen;
    } catch (e) {
      AppLogger.error('Saved login could not be read', error: e);
      return null;
    }
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
