import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// A text link ("Forgot password?", "Log in instead ›"). [chevron] adds the small arrow.
class KnTextLink extends StatelessWidget {
  const KnTextLink({
    super.key,
    required this.text,
    required this.onTap,
    this.chevron = false,
    this.large = false,
    this.textAlign,
  });

  final String text;
  final VoidCallback onTap;
  final bool chevron;

  /// 16 px label (bottom links) instead of the 14 px one.
  final bool large;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final style = large ? context.knText.label : context.knText.labelSm;
    return CustomInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KnSize.radiusSm),
      semanticLabel: text,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: CustomBaseTextWidget(text, style: style, color: kn.textLink, textAlign: textAlign)),
            if (chevron) ...[
              const SizedBox(width: KnSize.space4),
              Icon(LucideIcons.chevronRight, size: 16, color: kn.textLink),
            ],
          ],
        ),
      ),
    );
  }
}
