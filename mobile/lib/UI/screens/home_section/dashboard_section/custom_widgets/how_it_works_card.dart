import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../infrastructure/commons/constants/image_constants.dart';
import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M13 new company: "1 Technicians take photos · 2 AI writes the report · 3 You approve and send".
class HowItWorksCard extends StatelessWidget {
  const HowItWorksCard({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final lines = [LangKeys.dashHow1.tr, LangKeys.dashHow2.tr, LangKeys.dashHow3.tr];
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(ImageConstants.welcomeInvite, width: 72, height: 72, fit: BoxFit.cover),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: kn.actionPrimary, shape: BoxShape.circle),
                        child: CustomBaseTextWidget('${i + 1}', style: text.captionStrong, color: kn.textOnAction),
                      ),
                      const SizedBox(width: KnSize.space8),
                      Expanded(child: CustomBaseTextWidget(lines[i], style: text.caption, maxLines: 2)),
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

/// A quiet card with a round icon and two lines ("No reports to review yet").
class InfoRowCard extends StatelessWidget {
  const InfoRowCard({super.key, required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSubtle,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: kn.bgSurface, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: kn.textPrimary),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(title, style: text.label),
                const SizedBox(height: KnSize.space2),
                CustomBaseTextWidget(body, style: text.caption, color: kn.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
