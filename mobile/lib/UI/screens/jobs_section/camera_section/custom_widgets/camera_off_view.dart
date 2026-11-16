import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_page_scaffold.dart';
import '../../../../common_widgets/kn_screen_footer.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M20 "Camera is off" (Figma 22:1189): why the camera is needed and how to turn it on.
class CameraOffView extends StatelessWidget {
  const CameraOffView({super.key, required this.onOpenSettings, required this.onNotNow});

  final VoidCallback onOpenSettings;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final steps = [LangKeys.cameraHow1.tr, LangKeys.cameraHow2.tr, LangKeys.cameraHow3.tr];
    return KnPageScaffold(
      key: const ValueKey('camera-off'),
      onBack: onNotNow,
      footer: KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('open-settings'),
            text: LangKeys.cameraOpenSettings.tr,
            icon: LucideIcons.slidersHorizontal,
            onTap: onOpenSettings,
          ),
          KnCustomButton(text: LangKeys.cameraNotNow.tr, variant: KnButtonVariant.ghost, onTap: onNotNow),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(
              width: 140,
              height: 128,
              child: Stack(
                children: [
                  Positioned(
                    left: 10,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(color: kn.statusDangerBg, shape: BoxShape.circle),
                      child: Icon(LucideIcons.camera, size: 56, color: kn.statusDanger),
                    ),
                  ),
                  Positioned(
                    left: 92,
                    top: 84,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kn.bgSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: kn.bgCanvas, width: 4),
                      ),
                      child: Icon(LucideIcons.lock, size: 22, color: kn.statusDanger),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          CustomBaseTextWidget(LangKeys.cameraOffTitle.tr, style: text.h1, textAlign: TextAlign.center),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(
            LangKeys.cameraOffBody.tr,
            style: text.bodyLg,
            color: kn.textSecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(KnSize.space16),
            decoration: BoxDecoration(
              color: kn.bgSurface,
              borderRadius: BorderRadius.circular(KnSize.radiusLg),
              border: Border.all(color: kn.borderDefault),
              boxShadow: KnShadow.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(LangKeys.cameraHowTitle.tr, style: text.label),
                for (var i = 0; i < steps.length; i++) ...[
                  const SizedBox(height: KnSize.space12),
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
                        child: CustomBaseTextWidget('${i + 1}', style: text.label),
                      ),
                      const SizedBox(width: KnSize.space12),
                      Expanded(child: CustomBaseTextWidget(steps[i], style: text.body)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: KnSize.space24),
        ],
      ),
    );
  }
}
