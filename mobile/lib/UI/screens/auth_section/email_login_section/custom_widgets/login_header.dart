import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_brand_mark.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M06 dark header: decorative ring, the KaamNishaan lockup on dark, "Log in" and who it is for.
/// [top] is the status bar height; the design measures from below a 32 px status bar.
class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key, required this.top});

  final double top;

  static const double height = 268;

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    return Container(
      height: top + height,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: KnPrimitive.mocha900,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 200,
            top: top - 102,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: KnPrimitive.mocha700.withValues(alpha: 0.6), width: 28),
              ),
            ),
          ),
          Positioned(
            left: KnSize.space16,
            top: top + 32,
            child: const Row(
              children: [
                KnBrandMark(size: 39.2, onDark: true),
                SizedBox(width: 9.8),
                Text(
                  'KaamNishaan',
                  style: TextStyle(
                    fontFamily: 'Baloo 2',
                    fontVariations: [FontVariation('wght', 700)],
                    fontSize: 25.2,
                    letterSpacing: -0.252,
                    color: KnPrimitive.cream100,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: KnSize.space16,
            right: 44,
            top: top + 106,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(LangKeys.loginTitle.tr, style: text.display, color: KnPrimitive.cream50),
                const SizedBox(height: 6),
                CustomBaseTextWidget(LangKeys.loginSubtitle.tr, style: text.body, color: KnPrimitive.cream400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
