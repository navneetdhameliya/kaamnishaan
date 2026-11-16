import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../infrastructure/lang/lang_keys.g.dart';
import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// Red message under a field, with an optional "Hear it" button that reads it aloud.
class KnInlineError extends StatelessWidget {
  const KnInlineError({super.key, required this.message, this.onHear});

  final String message;
  final VoidCallback? onHear;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(LucideIcons.circleAlert, size: 16, color: kn.statusDanger),
        const SizedBox(width: 6),
        Expanded(
          child: CustomBaseTextWidget(message, style: context.knText.captionStrong, color: kn.statusDanger),
        ),
        if (onHear != null) ...[
          const SizedBox(width: KnSize.space8),
          KnHearItButton(onTap: onHear!),
        ],
      ],
    );
  }
}

/// Small pill with a speaker icon: reads a message aloud.
class KnHearItButton extends StatelessWidget {
  const KnHearItButton({super.key, required this.onTap, this.danger = true});

  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final fg = danger ? kn.statusDanger : kn.textPrimary;
    return CustomInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KnSize.radiusFull),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: danger ? kn.statusDangerBg : kn.bgSubtle,
          borderRadius: BorderRadius.circular(KnSize.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.volume2, size: 16, color: fg),
            const SizedBox(width: 4),
            CustomBaseTextWidget(LangKeys.commonHearIt.tr, style: context.knText.labelSm, color: fg),
          ],
        ),
      ),
    );
  }
}
