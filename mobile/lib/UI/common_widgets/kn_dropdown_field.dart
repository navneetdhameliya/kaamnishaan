import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// Labelled field that opens a choice sheet (M11 "Your work").
class KnDropdownField extends StatelessWidget {
  const KnDropdownField({super.key, required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomBaseTextWidget(label, style: context.knText.label),
        const SizedBox(height: KnSize.space8),
        CustomInkWell(
          onTap: onTap,
          borderRadius: radius,
          semanticLabel: label,
          child: Ink(
            height: KnSize.tapTechnician,
            padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
            decoration: BoxDecoration(
              color: kn.bgSurface,
              borderRadius: radius,
              border: Border.all(color: kn.borderStrong),
            ),
            child: Row(
              children: [
                Expanded(child: CustomBaseTextWidget(value, style: context.knText.body, maxLines: 1)),
                Icon(LucideIcons.chevronDown, size: 22, color: kn.textPrimary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
