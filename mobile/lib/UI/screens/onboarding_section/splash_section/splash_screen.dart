import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_brand_mark.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/loading_dots.dart';
import 'splash_controller.dart';

/// M01 Splash (Figma 15:769). Always dark (brand), in light and dark mode.
class SplashScreen extends GetView<SplashController> {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const cream = KnPrimitive.cream100;
    const muted = KnPrimitive.cream400;
    return Scaffold(
      backgroundColor: KnPrimitive.mocha900,
      body: Stack(
        children: [
          const Positioned(right: -140, top: -120, child: _Ring(size: 360)),
          const Positioned(left: -150, bottom: -60, child: _Ring(size: 300)),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(flex: 5),
                  const KnBrandMark(size: 96, onDark: true),
                  const SizedBox(height: KnSize.space12),
                  const Text(
                    'KaamNishaan',
                    style: TextStyle(
                      fontFamily: 'Baloo 2',
                      fontVariations: [FontVariation('wght', 700)],
                      fontSize: 44,
                      letterSpacing: -0.44,
                      height: 1.25,
                      color: cream,
                    ),
                  ),
                  const SizedBox(height: KnSize.space12),
                  // brand tagline: always English, as in the logo lockup
                  const Text(
                    'Every Job. Every Photo. Every Proof.',
                    style: TextStyle(
                      fontFamily: 'DM Sans',
                      fontVariations: [FontVariation('wght', 600), FontVariation('opsz', 14)],
                      fontSize: 16,
                      color: cream,
                    ),
                  ),
                  const SizedBox(height: KnSize.space24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: KnSize.space32),
                    child: CustomBaseTextWidget(
                      LangKeys.splashSubtitle.tr,
                      style: context.knText.caption,
                      color: muted,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(flex: 4),
                  const LoadingDots(),
                  const SizedBox(height: 30),
                  Obx(
                    () => CustomBaseTextWidget(
                      controller.version.value.isEmpty
                          ? ' '
                          : LangKeys.commonVersion.trParams({'version': controller.version.value}),
                      style: context.knText.caption,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: KnSize.space32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two soft decorative rings (Figma "Deco ring").
class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: KnPrimitive.mocha800, width: size * 0.1),
        ),
      );
}
