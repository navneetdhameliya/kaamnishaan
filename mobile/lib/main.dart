import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import 'UI/screens/onboarding_section/startup_error_section/startup_error_screen.dart';
import 'UI/theme/kn_app_theme.dart';
import 'infrastructure/commons/constants/app_pages.dart';
import 'infrastructure/commons/constants/app_routes.dart';
import 'infrastructure/lang/translation_service.dart';
import 'infrastructure/lang/translations.g.dart';
import 'infrastructure/services/app_services.dart';
import 'infrastructure/shared/app_logger.dart';

/// The longest the app setup may take before the error screen shows (it never waits on a blank splash).
const startupLimit = Duration(seconds: 20);

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppLogger.error('Flutter error', error: details.exception, stackTrace: details.stack);
    };
    await start();
  }, (error, stack) => AppLogger.error('Uncaught error', error: error, stackTrace: stack));
}

/// Sets up the services, then shows the app; if setup fails or hangs, shows "couldn't start" with Try again.
Future<void> start() async {
  try {
    if (!AppServices.ready) await AppServices.init().timeout(startupLimit);
    runApp(KaamNishaanApp(locale: Get.find<TranslationService>().startLocale));
  } catch (error, stack) {
    AppLogger.error('KaamNishaan could not start', error: error, stackTrace: stack);
    runApp(StartupErrorApp(error: error, onRetry: () => unawaited(start())));
  }
}

class KaamNishaanApp extends StatelessWidget {
  const KaamNishaanApp({super.key, required this.locale, this.initialRoute = RoutesConstants.splashScreen});

  final Locale locale;
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: GetMaterialApp(
        title: 'KaamNishaan',
        debugShowCheckedModeBanner: false,
        translations: KnTranslations(),
        locale: locale,
        fallbackLocale: TranslationService.fallbackLocale,
        supportedLocales: TranslationService.supportedLocales,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: KnTheme.light(locale),
        darkTheme: KnTheme.dark(locale),
        themeMode: ThemeMode.system,
        initialRoute: initialRoute,
        getPages: AppPages.pages,
      ),
    );
  }
}
