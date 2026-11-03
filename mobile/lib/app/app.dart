import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import '../core/i18n/kn_translations.g.dart';
import '../core/theme/kn_theme.dart';
import 'routes.dart';

const supportedLocales = [Locale('en', 'IN'), Locale('hi', 'IN'), Locale('gu', 'IN'), Locale('es', 'ES'), Locale('fr', 'FR')];

class KaamNishaanApp extends StatelessWidget {
  const KaamNishaanApp({super.key, this.locale = const Locale('en', 'IN')});
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'KaamNishaan',
      debugShowCheckedModeBanner: false,
      translations: KnTranslations(),
      locale: locale,
      fallbackLocale: const Locale('en', 'IN'),
      supportedLocales: supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: KnTheme.light(locale),
      darkTheme: KnTheme.dark(locale),
      themeMode: ThemeMode.system,
      initialRoute: Routes.home,
      getPages: AppPages.pages,
    );
  }
}
