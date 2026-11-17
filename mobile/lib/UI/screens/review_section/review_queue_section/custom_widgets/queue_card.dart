import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../../infrastructure/shared/text_utils.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// One report in the review queue: the job, who sent it and when, its newest photos and how long it waits.
class QueueCard extends StatelessWidget {
  const QueueCard({
    super.key,
    required this.report,
    required this.meta,
    required this.byLine,
    required this.onTap,
    this.waitChip,
    this.oldest = false,
  });

  final ReportListItemModel report;
  final String meta;
  final String byLine;
  final String? waitChip;
  final bool oldest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final thumbs = report.thumbs ?? const <String>[];
    final more = (report.job.photos ?? 0) - thumbs.length;
    final tech = report.job.technician;
    Widget chip(IconData icon, String label, Color bg, Color fg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              CustomBaseTextWidget(label, style: text.labelSm, color: fg),
            ],
          ),
        );
    return CustomInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KnSize.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: BorderRadius.circular(KnSize.radiusLg),
          border: Border.all(color: oldest ? kn.statusWarning : kn.borderDefault, width: oldest ? 1.5 : 1),
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
                      CustomBaseTextWidget(meta, style: text.caption, color: kn.textSecondary, maxLines: 1),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          KnInitialsAvatar(
                            initials: TextUtils.initials(tech?.name ?? ''),
                            url: tech?.avatarUrl,
                            size: 20,
                            borderWidth: 0,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: CustomBaseTextWidget(byLine, style: text.caption, color: kn.textSecondary, maxLines: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 20, color: kn.textSecondary),
              ],
            ),
            if (thumbs.isNotEmpty) ...[
              const SizedBox(height: KnSize.space12),
              Row(
                children: [
                  for (final t in thumbs) ...[
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(KnSize.radiusMd),
                        child: AspectRatio(aspectRatio: 1.3, child: KnCoverImage(url: t)),
                      ),
                    ),
                    const SizedBox(width: KnSize.space8),
                  ],
                  for (var i = thumbs.length; i < 3; i++) ...[const Expanded(child: SizedBox()), const SizedBox(width: 8)],
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1.3,
                      child: more > 0
                          ? Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: kn.actionSecondary,
                                borderRadius: BorderRadius.circular(KnSize.radiusMd),
                              ),
                              child: CustomBaseTextWidget('+$more', style: text.label),
                            )
                          : const SizedBox(),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: KnSize.space12),
            Wrap(
              spacing: KnSize.space8,
              runSpacing: KnSize.space8,
              children: [
                if (waitChip != null)
                  oldest
                      ? chip(LucideIcons.clock, waitChip!, kn.statusWarningBg, kn.statusWarning)
                      : chip(LucideIcons.clock, waitChip!, kn.actionSecondary, kn.textPrimary),
                if (report.status == 'pending_review' && report.draftedBy == 'ai')
                  chip(LucideIcons.sparkle, LangKeys.queueAiReady.tr, kn.actionSecondary, kn.textPrimary),
                if (report.status == 'changes_requested')
                  chip(LucideIcons.circleAlert, LangKeys.reportChangesAsked.tr, kn.statusDangerBg, kn.statusDanger),
                if (const {'approved', 'shared', 'acknowledged'}.contains(report.status))
                  chip(
                    LucideIcons.check,
                    report.status == 'approved' ? LangKeys.reportApproved.tr : LangKeys.myreportsApprovedSent.tr,
                    kn.statusSuccessBg,
                    kn.statusSuccess,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
