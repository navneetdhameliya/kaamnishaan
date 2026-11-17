import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translations.g.dart';
import '../../../theme/kn_tokens.g.dart';

/// Shown instead of a frozen launch screen when the app's setup fails (it never waits forever).
/// "Try again" runs the setup again. In debug builds the error is shown too, to report it.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      translations: KnTranslations(),
      locale: Get.deviceLocale,
      fallbackLocale: const Locale('en', 'IN'),
      home: Scaffold(
        backgroundColor: KnPrimitive.mocha900,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(KnSize.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Icon(LucideIcons.cloudOff, size: 48, color: KnPrimitive.cream100),
                const SizedBox(height: KnSize.space16),
                Text(
                  LangKeys.startupTitle.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: KnPrimitive.cream50, fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: KnSize.space8),
                Text(
                  LangKeys.startupBody.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: KnPrimitive.cream400, fontSize: 16),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: KnSize.space16),
                  SelectableText(
                    '$error',
                    key: const ValueKey('startup-error-detail'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: KnPrimitive.cream400, fontSize: 12),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    key: const ValueKey('startup-retry'),
                    style: FilledButton.styleFrom(
                      backgroundColor: KnPrimitive.cream50,
                      foregroundColor: KnPrimitive.mocha900,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KnSize.radiusLg)),
                    ),
                    onPressed: onRetry,
                    child: Text(LangKeys.startupRetry.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
