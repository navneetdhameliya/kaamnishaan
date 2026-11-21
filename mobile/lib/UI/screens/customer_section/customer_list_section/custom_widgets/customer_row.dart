import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// One customer in the list: initials, the name, who to call and where, and how many jobs.
class CustomerRow extends StatelessWidget {
  const CustomerRow({
    super.key,
    required this.name,
    required this.initials,
    required this.line,
    required this.jobs,
    required this.divider,
    required this.onTap,
  });

  final String name;
  final String initials;
  final String line;
  final String jobs;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return CustomInkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: KnSize.space12),
        decoration: BoxDecoration(
          border: divider ? Border(bottom: BorderSide(color: kn.borderDefault)) : null,
        ),
        child: Row(
          children: [
            KnInitialsAvatar(initials: initials, size: 44, borderWidth: 0),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(name, style: text.label, maxLines: 1),
                  if (line.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    CustomBaseTextWidget(line, style: text.caption, color: kn.textSecondary, maxLines: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(width: KnSize.space8),
            CustomBaseTextWidget(jobs, style: text.labelSm, color: kn.textSecondary),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 18, color: kn.textSecondary),
          ],
        ),
      ),
    );
  }
}
