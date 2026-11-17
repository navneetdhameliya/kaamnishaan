import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import 'custom_inkwell.dart';

/// The top of a screen: a round back (or close) button, the title and a small line under it.
class KnTitleBar extends StatelessWidget {
  const KnTitleBar({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = LucideIcons.chevronLeft,
    this.onBack,
    this.buttonKey,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onBack;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final sub = subtitle;
    return Row(
      children: [
        CustomInkWell(
          key: buttonKey,
          onTap: onBack ?? Get.back,
          borderRadius: BorderRadius.circular(22),
          semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kn.bgSurface,
              border: Border.all(color: kn.borderDefault),
            ),
            child: Icon(icon, size: 22, color: kn.textPrimary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBaseTextWidget(title, style: text.h3, maxLines: 1),
              if (sub != null && sub.isNotEmpty)
                CustomBaseTextWidget(sub, style: text.caption, color: kn.textSecondary, maxLines: 1),
            ],
          ),
        ),
      ],
    );
  }
}
