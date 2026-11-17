import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// One report on M30: the job, its number and time, and where it is. "Changes asked" shows the
/// manager's words and "Fix the report".
class MyReportCard extends StatelessWidget {
  const MyReportCard({
    super.key,
    required this.report,
    required this.meta,
    required this.when,
    required this.status,
    required this.onTap,
    required this.onFix,
  });

  final ReportListItemModel report;
  final String meta;
  final String when;
  final String status;
  final VoidCallback onTap;
  final VoidCallback onFix;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final changes = report.status == 'changes_requested';
    final (Color bg, Color fg, IconData icon) = switch (report.status) {
      'changes_requested' => (kn.statusDangerBg, kn.statusDanger, LucideIcons.circleAlert),
      'pending_review' => (kn.actionSecondary, kn.textPrimary, LucideIcons.clock),
      'approved' || 'shared' || 'acknowledged' => (kn.statusSuccessBg, kn.statusSuccess, LucideIcons.check),
      _ => (kn.actionSecondary, kn.textSecondary, LucideIcons.pencil),
    };
    final note = report.changeNote?.trim();
    return CustomInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KnSize.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: BorderRadius.circular(KnSize.radiusLg),
          border: Border.all(color: changes ? kn.statusDanger : kn.borderDefault, width: changes ? 1.5 : 1),
          boxShadow: KnShadow.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(KnSize.radiusMd),
                  child: KnCoverImage(url: report.job.coverUrl, width: 64, height: 64),
                ),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomBaseTextWidget(report.job.customer, style: text.label, maxLines: 1),
                      const SizedBox(height: 2),
                      CustomBaseTextWidget(meta, style: text.caption, color: kn.textSecondary, maxLines: 1),
                      CustomBaseTextWidget(when, style: text.caption, color: kn.textSecondary, maxLines: 1),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 20, color: kn.textSecondary),
              ],
            ),
            const SizedBox(height: KnSize.space12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: fg),
                  const SizedBox(width: 6),
                  CustomBaseTextWidget(status, style: text.labelSm, color: fg),
                ],
              ),
            ),
            if (changes && note != null && note.isNotEmpty) ...[
              const SizedBox(height: KnSize.space12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KnSize.space12),
                decoration: BoxDecoration(color: kn.statusDangerBg, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                child: CustomBaseTextWidget('“$note”', style: text.body),
              ),
            ],
            if (changes) ...[
              const SizedBox(height: KnSize.space12),
              KnCustomButton(
                key: ValueKey('fix-${report.id}'),
                text: LangKeys.myreportsFix.tr,
                icon: LucideIcons.wrench,
                onTap: onFix,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
