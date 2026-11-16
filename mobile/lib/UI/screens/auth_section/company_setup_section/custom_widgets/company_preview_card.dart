import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M07 live preview: "BrightAir Services · HVAC · United States · Owner Suresh" (Figma "Preview").
class CompanyPreviewCard extends StatelessWidget {
  const CompanyPreviewCard({super.key, required this.name, required this.meta, required this.isPlaceholder});

  final String name;
  final String meta;
  final bool isPlaceholder;

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
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: kn.actionPrimary, shape: BoxShape.circle),
            child: Icon(LucideIcons.building, size: 20, color: kn.textOnAction),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(
                  name,
                  style: text.label,
                  color: isPlaceholder ? kn.textSecondary : kn.textPrimary,
                  maxLines: 1,
                ),
                const SizedBox(height: KnSize.space2),
                CustomBaseTextWidget(meta, style: text.caption, color: kn.textSecondary, maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
