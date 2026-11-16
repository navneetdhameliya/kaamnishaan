import 'package:flutter/material.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

enum KnButtonVariant { primary, secondary, ghost, danger }

/// Figma "Button": Large (56) is the technician size. Primary = the one main action per screen.
/// A disabled button still reacts to taps through [onDisabledTap] so it can say why (design rule).
class KnCustomButton extends StatelessWidget {
  const KnCustomButton({
    super.key,
    required this.text,
    this.onTap,
    this.icon,
    this.variant = KnButtonVariant.primary,
    this.loading = false,
    this.enabled = true,
    this.onDisabledTap,
    this.small = false,
    this.height,
    this.dense = false,
  });

  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final KnButtonVariant variant;
  final bool loading;
  final bool enabled;
  final VoidCallback? onDisabledTap;

  /// 40 px tall, for buttons inside a card row (M13 "Invite", "Create").
  final bool small;

  /// Overrides the height (M15 "Navigate" and "Call" are 48).
  final double? height;

  /// Tighter sides (12 px) for two buttons side by side with long words.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final active = enabled && onTap != null;
    final (Color bg, Color fg) = switch (variant) {
      _ when !active => (kn.actionDisabled, kn.borderStrong),
      KnButtonVariant.primary => (kn.actionPrimary, kn.textOnAction),
      KnButtonVariant.secondary => (kn.actionSecondary, kn.textPrimary),
      KnButtonVariant.ghost => (Colors.transparent, kn.textLink),
      KnButtonVariant.danger => (kn.statusDanger, kn.textOnAction),
    };
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: loading ? null : (active ? onTap : onDisabledTap),
      borderRadius: radius,
      semanticLabel: text,
      child: Ink(
        height: height ?? (small ? 40 : KnSize.tapTechnician),
        decoration: BoxDecoration(color: bg, borderRadius: radius),
        padding: EdgeInsets.symmetric(
          horizontal: dense ? KnSize.space12 : (small ? KnSize.space16 : (height != null ? KnSize.space20 : KnSize.space24)),
        ),
        child: Center(
          child: loading
              ? SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: KnSize.space8)],
                    Flexible(
                      child: CustomBaseTextWidget(
                        text,
                        style: context.knText.label,
                        color: fg,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
