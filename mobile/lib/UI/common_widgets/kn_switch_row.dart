import 'package:flutter/material.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// A settings line with a title, a small line under it and a switch on the right (M46, M35).
/// The whole row is the tap target; [enabled] false shows it faded and does nothing.
class KnSwitchRow extends StatelessWidget {
  const KnSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.padding = const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: KnSize.space12),
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final sub = subtitle;
    return CustomInkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      semanticLabel: title,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(title, style: text.label),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    CustomBaseTextWidget(sub, style: text.caption, color: kn.textSecondary),
                  ],
                ],
              ),
            ),
            const SizedBox(width: KnSize.space12),
            IgnorePointer(
              child: Opacity(
                opacity: enabled ? 1 : 0.6,
                child: Switch(
                  value: value,
                  onChanged: (_) {},
                  activeThumbColor: kn.bgSurface,
                  activeTrackColor: kn.actionPrimary,
                  inactiveThumbColor: kn.bgSurface,
                  inactiveTrackColor: kn.borderStrong,
                  trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
