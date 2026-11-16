import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M12 "Next up" row: picture, customer, what the job is, and the time. A done job gets a green tick.
class JobRowCard extends StatelessWidget {
  const JobRowCard({super.key, required this.job, required this.time, required this.onTap});

  final JobListItemModel job;
  final String time;
  final VoidCallback onTap;

  bool get done => job.status == 'in_review' || job.status == 'completed';

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: job.customer.name,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(KnSize.space8, KnSize.space8, KnSize.space12, KnSize.space8),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: kn.borderDefault),
          boxShadow: KnShadow.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  KnCoverImage(url: job.coverUrl, width: 56, height: 56, radius: 12),
                  if (done)
                    Positioned(
                      left: 38,
                      top: 38,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: kn.statusSuccess,
                          shape: BoxShape.circle,
                          border: Border.all(color: kn.bgSurface, width: 2),
                        ),
                        child: const Icon(LucideIcons.check, size: 14, color: KnPrimitive.cream50),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(job.customer.name, style: text.bodyLg, maxLines: 1),
                  const SizedBox(height: KnSize.space2),
                  CustomBaseTextWidget(
                    done ? LangKeys.todayJobDone.trParams({'title': job.title}) : job.title,
                    style: text.caption,
                    color: done ? kn.statusSuccess : kn.textSecondary,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(width: KnSize.space12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: KnSize.space8, vertical: KnSize.space4),
                decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                child: CustomBaseTextWidget(time, style: text.labelSm),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
