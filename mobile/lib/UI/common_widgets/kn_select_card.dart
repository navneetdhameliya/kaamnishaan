import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// A choice card with a radio circle and an optional speaker button (M02 language list).
class KnSelectCard extends StatelessWidget {
  const KnSelectCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.titleStyle,
    this.onSpeak,
  });

  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onSpeak;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: title,
      child: Ink(
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: selected ? kn.actionPrimary : kn.borderDefault, width: selected ? 2 : 1),
          boxShadow: KnShadow.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomBaseTextWidget(title, style: titleStyle ?? context.knText.h3),
                  if (subtitle != null)
                    CustomBaseTextWidget(subtitle!, style: KnText.latin.caption, color: kn.textSecondary),
                ],
              ),
            ),
            if (onSpeak != null) ...[
              CustomInkWell(
                onTap: onSpeak,
                borderRadius: BorderRadius.circular(22),
                semanticLabel: title,
                child: Ink(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
                  child: Icon(LucideIcons.volume2, size: 22, color: kn.textPrimary),
                ),
              ),
              const SizedBox(width: KnSize.space12),
            ],
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? kn.actionPrimary : kn.bgSurface,
                shape: BoxShape.circle,
                border: selected ? null : Border.all(color: kn.borderStrong, width: 2),
              ),
              child: selected ? Icon(LucideIcons.check, size: 16, color: kn.textOnAction) : null,
            ),
          ],
        ),
      ),
    );
  }
}
