import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_back_button.dart';
import '../../../../commons/behaviour/behaviour.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M27 "Microphone is off" (Figma 28:1391).
class MicOffView extends StatelessWidget {
  const MicOffView({super.key, required this.onBackTap});

  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final steps = [LangKeys.voiceOffStep1.tr, LangKeys.voiceOffStep2.tr, LangKeys.voiceOffStep3.tr];
    return ScrollConfiguration(
      behavior: const KnScrollBehavior(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
        children: [
          Align(alignment: Alignment.centerLeft, child: KnBackButton(onTap: onBackTap)),
          const SizedBox(height: KnSize.space8),
          Center(
            child: SizedBox.square(
              dimension: 120,
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusDangerBg),
                    child: Icon(LucideIcons.mic, size: 44, color: kn.statusDanger),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 4,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kn.bgSurface,
                        boxShadow: KnShadow.sm,
                      ),
                      child: Icon(LucideIcons.lock, size: 20, color: kn.statusDanger),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KnSize.space24),
          CustomBaseTextWidget(LangKeys.voiceOffTitle.tr, style: text.h1, textAlign: TextAlign.center),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(
            LangKeys.voiceOffBody.tr,
            style: text.bodyLg,
            color: kn.textSecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KnSize.space32),
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
                CustomBaseTextWidget(LangKeys.voiceOffHow.tr, style: text.label),
                for (var i = 0; i < steps.length; i++) ...[
                  const SizedBox(height: KnSize.space12),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
                        child: CustomBaseTextWidget('${i + 1}', style: text.labelSm),
                      ),
                      const SizedBox(width: KnSize.space12),
                      Expanded(child: CustomBaseTextWidget(steps[i], style: text.body)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
