import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../../infrastructure/shared/text_utils.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M13 "Waiting for your review" row: picture, customer, who sent it and when, photos and AI draft.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.report, required this.meta, required this.evidence, required this.onTap});

  final ReportListItemModel report;
  final String meta;
  final String evidence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final tech = report.job.technician;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: report.job.customer,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(KnSize.space8, KnSize.space8, KnSize.space12, KnSize.space8),
        decoration: BoxDecoration(color: kn.bgSurface, borderRadius: radius, border: Border.all(color: kn.borderDefault)),
        child: Row(
          children: [
            KnCoverImage(url: report.job.coverUrl, width: 64, height: 64, radius: 12),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(report.job.customer, style: text.label, maxLines: 1),
                  const SizedBox(height: KnSize.space4),
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
                        child: CustomBaseTextWidget(meta, style: text.caption, color: kn.textSecondary, maxLines: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space4),
                  Row(
                    children: [
                      Icon(LucideIcons.image, size: 14, color: kn.textSecondary),
                      const SizedBox(width: KnSize.space4),
                      Expanded(
                        child: CustomBaseTextWidget(evidence, style: text.caption, color: kn.textSecondary, maxLines: 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: KnSize.space12),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: kn.actionPrimary, shape: BoxShape.circle),
              child: Icon(LucideIcons.chevronRight, size: 18, color: kn.textOnAction),
            ),
          ],
        ),
      ),
    );
  }
}
