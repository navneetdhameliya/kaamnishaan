import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import 'UI/theme/kn_app_theme.dart';
import 'infrastructure/commons/constants/app_pages.dart';
import 'infrastructure/commons/constants/app_routes.dart';
import 'infrastructure/lang/translation_service.dart';
import 'infrastructure/lang/translations.g.dart';
import 'infrastructure/services/app_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.init();
  runApp(KaamNishaanApp(locale: Get.find<TranslationService>().startLocale));
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
