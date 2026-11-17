import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_stars.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// One review on M44: who, where, when, the stars, the words and the manager's reply.
class ReviewTile extends StatelessWidget {
  const ReviewTile({
    super.key,
    required this.name,
    required this.meta,
    required this.ago,
    required this.rating,
    required this.onTap,
    this.coverUrl,
    this.comment,
    this.repliedBy,
    this.reply,
  });

  final String name;
  final String meta;
  final String ago;
  final int rating;
  final String? coverUrl;
  final String? comment;
  final String? repliedBy;
  final String? reply;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    final words = comment;
    final answer = reply;
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: name,
      child: Ink(
        padding: const EdgeInsets.all(KnSize.space16),
        decoration: BoxDecoration(color: kn.bgSurface, borderRadius: radius, border: Border.all(color: kn.borderDefault)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KnCoverImage(url: coverUrl, width: 40, height: 40, radius: KnSize.radiusMd, placeholderIcon: LucideIcons.wrench),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomBaseTextWidget(name, style: text.label, maxLines: 1),
                      CustomBaseTextWidget(meta, style: text.caption, color: kn.textSecondary, maxLines: 2),
                    ],
                  ),
                ),
                const SizedBox(width: KnSize.space8),
                CustomBaseTextWidget(ago, style: text.caption, color: kn.textSecondary),
              ],
            ),
            const SizedBox(height: KnSize.space8),
            KnStars(rating: rating, size: 16),
            if (words != null && words.isNotEmpty) ...[
              const SizedBox(height: KnSize.space8),
              CustomBaseTextWidget(words, style: text.body, maxLines: 4),
            ],
            if (answer != null) ...[
              const SizedBox(height: KnSize.space12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KnSize.space12),
                decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (repliedBy != null)
                      CustomBaseTextWidget(repliedBy!, style: text.captionStrong, color: kn.textSecondary),
                    const SizedBox(height: 2),
                    CustomBaseTextWidget(answer, style: text.caption, maxLines: 3),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
