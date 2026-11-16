import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../infrastructure/lang/lang_keys.g.dart';
import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';

/// A job's status as a small pill with an icon ("In progress", "Review", "Assigned", "Done"…).
class KnJobStatusPill extends StatelessWidget {
  const KnJobStatusPill({super.key, required this.status});

  final String status;

  static String label(String status) => switch (status) {
        'unassigned' => LangKeys.statusUnassigned.tr,
        'assigned' => LangKeys.statusAssigned.tr,
        'in_progress' => LangKeys.statusInProgress.tr,
        'in_review' => LangKeys.statusInReview.tr,
        'changes_requested' => LangKeys.statusChangesRequested.tr,
        'completed' => LangKeys.statusCompleted.tr,
        _ => LangKeys.statusCancelled.tr,
      };

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final (IconData icon, Color fg, Color bg) = switch (status) {
      'unassigned' => (LucideIcons.userPlus, kn.statusWarning, kn.statusWarningBg),
      'assigned' => (LucideIcons.user, kn.textSecondary, kn.bgSubtle),
      'in_progress' => (LucideIcons.clock, kn.textSecondary, kn.bgSubtle),
      'in_review' => (LucideIcons.clock, kn.statusWarning, kn.statusWarningBg),
      'changes_requested' => (LucideIcons.circleAlert, kn.statusDanger, kn.statusDangerBg),
      'completed' => (LucideIcons.check, kn.statusSuccess, kn.statusSuccessBg),
      _ => (LucideIcons.x, kn.textSecondary, kn.bgSubtle),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: KnSize.space4),
          CustomBaseTextWidget(label(status), style: context.knText.labelSm, color: fg, maxLines: 1),
        ],
      ),
    );
  }
}
