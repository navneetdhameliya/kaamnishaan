import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_cover_image.dart';
import '../../../common_widgets/kn_stars.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'review_details_controller.dart';

/// M44 Review details (Figma 265:2420).
class ReviewDetailsScreen extends GetView<ReviewDetailsController> {
  const ReviewDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: Obx(() {
            final r = controller.review.value;
            return ListView(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                KnTitleBar(title: LangKeys.rdTitle.tr, subtitle: controller.subtitle),
                const SizedBox(height: KnSize.space16),
                if (r == null)
                  const CommonShimmer(height: 360, radius: KnSize.radiusLg)
                else ...[
                  if (r.beforeUrl != null || r.afterUrl != null) ...[
                    Row(
                      children: [
                        for (final (i, url) in [r.beforeUrl, r.afterUrl].indexed) ...[
                          if (i == 1) const SizedBox(width: KnSize.space8),
                          Expanded(
                            child: KnCoverImage(url: url, height: 110, radius: KnSize.radiusLg, placeholderIcon: LucideIcons.image),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: KnSize.space12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(KnSize.space16),
                    decoration: BoxDecoration(
                      color: kn.bgSurface,
                      borderRadius: BorderRadius.circular(KnSize.radiusLg),
                      border: Border.all(color: kn.borderDefault),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            KnCoverImage(url: r.coverUrl, width: 44, height: 44, radius: KnSize.radiusMd, placeholderIcon: LucideIcons.wrench),
                            const SizedBox(width: KnSize.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomBaseTextWidget(controller.name, style: text.label, maxLines: 1),
                                  CustomBaseTextWidget(controller.meta, style: text.caption, color: kn.textSecondary),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: KnSize.space12),
                        _StarsRow(label: LangKeys.rdService.tr, rating: r.rating),
                        if (r.technicianRating != null) _StarsRow(label: controller.youLabel, rating: r.technicianRating!),
                        if (controller.quote != null) ...[
                          const SizedBox(height: KnSize.space8),
                          CustomBaseTextWidget(controller.quote!, style: text.bodyLg),
                        ],
                        if (controller.tags.isNotEmpty) ...[
                          const SizedBox(height: KnSize.space12),
                          Wrap(
                            spacing: KnSize.space8,
                            runSpacing: KnSize.space8,
                            children: [
                              for (final t in controller.tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kn.bgSubtle,
                                    borderRadius: BorderRadius.circular(KnSize.radiusFull),
                                  ),
                                  child: CustomBaseTextWidget(t, style: text.labelSm),
                                ),
                            ],
                          ),
                        ],
                        if (r.reply != null) ...[
                          const SizedBox(height: KnSize.space16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(KnSize.space12),
                            decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomBaseTextWidget(controller.replyBy ?? '', style: text.captionStrong, color: kn.textSecondary),
                                const SizedBox(height: 2),
                                CustomBaseTextWidget(r.reply!.text, style: text.caption),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: KnSize.space12),
                  Container(
                    padding: const EdgeInsets.all(KnSize.space16),
                    decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(LucideIcons.lock, size: 18, color: kn.textSecondary),
                        const SizedBox(width: KnSize.space12),
                        Expanded(child: CustomBaseTextWidget(LangKeys.rdPrivate.tr, style: text.labelSm, color: kn.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.label, required this.rating});

  final String label;
  final int rating;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: CustomBaseTextWidget(label, style: context.knText.labelSm, color: kn.textSecondary)),
          KnStars(rating: rating, size: 18),
        ],
      ),
    );
  }
}
