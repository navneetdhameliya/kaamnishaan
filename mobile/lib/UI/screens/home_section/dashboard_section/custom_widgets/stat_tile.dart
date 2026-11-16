import 'package:flutter/material.dart';

import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M13 tile: icon, big number, label ("2 To review"). [highlight] draws the amber border.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
    required this.onTap,
    this.highlight,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final int value;
  final String label;
  final VoidCallback onTap;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: '$value $label',
      child: Ink(
        height: 118,
        padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: KnSize.space8),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: highlight ?? kn.borderDefault, width: highlight == null ? 1 : 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: KnSize.space4),
            CustomBaseTextWidget('$value', style: context.knText.h1),
            const SizedBox(height: KnSize.space4),
            CustomBaseTextWidget(label, style: context.knText.caption, color: kn.textSecondary, maxLines: 1),
          ],
        ),
      ),
    );
  }
}
