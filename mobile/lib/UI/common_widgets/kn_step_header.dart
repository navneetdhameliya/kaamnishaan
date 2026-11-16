import 'package:flutter/material.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'kn_back_button.dart';

/// Top of a step-by-step form (M07): back button, title, "Step 1 of 2 · …" and the step bars.
class KnStepHeader extends StatelessWidget {
  const KnStepHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.steps,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final int step;
  final int steps;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            KnBackButton(onTap: onBack),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(title, style: text.h3, maxLines: 1),
                  CustomBaseTextWidget(subtitle, style: text.caption, color: kn.textSecondary, maxLines: 1),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 1; i <= steps; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= step ? kn.actionPrimary : kn.borderDefault,
                    borderRadius: BorderRadius.circular(KnSize.radiusFull),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
