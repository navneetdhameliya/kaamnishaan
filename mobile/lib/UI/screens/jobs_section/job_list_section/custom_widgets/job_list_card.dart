import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../../infrastructure/shared/text_utils.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../common_widgets/kn_job_status_pill.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M14 row: picture, customer, "AC not cooling · 11:30 AM", who does it, and the status.
class JobListCard extends StatelessWidget {
  const JobListCard({super.key, required this.job, required this.time, required this.showAssignee, required this.onTap});

  final JobListItemModel job;
  final String time;
  final bool showAssignee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    final who = job.assignee;
    return CustomInkWell(
      key: ValueKey('job-${job.id}'),
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: job.customer.name,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: KnSize.space8),
        decoration: BoxDecoration(color: kn.bgSurface, borderRadius: radius, border: Border.all(color: kn.borderDefault)),
        child: Row(
          children: [
            KnCoverImage(url: job.coverUrl, width: 64, height: 64, radius: 12),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(job.customer.name, style: text.label, maxLines: 1),
                  const SizedBox(height: KnSize.space2),
                  Row(
                    children: [
                      Icon(LucideIcons.clock, size: 14, color: kn.textSecondary),
                      const SizedBox(width: KnSize.space4),
                      Expanded(
                        child: CustomBaseTextWidget(
                          [job.title, time].where((s) => s.isNotEmpty).join(' · '),
                          style: text.caption,
                          color: kn.textSecondary,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space2),
                  Row(
                    children: [
                      if (showAssignee && who != null) ...[
                        KnInitialsAvatar(
                          initials: TextUtils.initials(who.name),
                          url: who.avatarUrl,
                          size: 20,
                          borderWidth: 0,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: CustomBaseTextWidget(
                            TextUtils.firstName(who.name),
                            style: text.captionStrong,
                            maxLines: 1,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      KnJobStatusPill(status: job.status),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
