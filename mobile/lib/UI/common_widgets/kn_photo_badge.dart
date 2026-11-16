import 'package:flutter/material.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';

enum KnBadgeTone { light, success }

/// The small pills laid over photos ("BEFORE · photo 1", "Saved as proof").
class KnPhotoBadge extends StatelessWidget {
  const KnPhotoBadge({super.key, required this.text, this.icon, this.tone = KnBadgeTone.light, this.dot = false});

  final String text;
  final IconData? icon;
  final KnBadgeTone tone;

  /// Red recording dot before the icon.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final light = tone == KnBadgeTone.light;
    final fg = light ? kn.textPrimary : kn.textOnAction;
    return Container(
      padding: const EdgeInsets.fromLTRB(KnSize.space12, 6, KnSize.space12, KnSize.space8),
      decoration: BoxDecoration(
        color: light ? kn.bgSurface : kn.statusSuccess,
        borderRadius: BorderRadius.circular(KnSize.radiusFull),
        boxShadow: light ? KnShadow.sm : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: kn.statusDanger, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
          CustomBaseTextWidget(text, style: context.knText.labelSm, color: fg, maxLines: 1),
        ],
      ),
    );
  }
}
