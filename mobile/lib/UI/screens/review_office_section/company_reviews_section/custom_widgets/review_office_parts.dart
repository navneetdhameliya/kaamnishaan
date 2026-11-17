import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../../infrastructure/shared/review_words.dart';
import '../../../../../infrastructure/shared/text_utils.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../common_widgets/kn_stars.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// A round white button at the top-right of a screen (M45 "settings" sliders).
class OfficeRoundButton extends StatelessWidget {
  const OfficeRoundButton({super.key, required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return CustomInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KnSize.radiusFull),
      semanticLabel: label,
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: kn.bgSurface, shape: BoxShape.circle, border: Border.all(color: kn.borderDefault)),
        child: Icon(icon, size: 22, color: kn.textPrimary),
      ),
    );
  }
}

/// The big average with stars, and a bar for each star count (M45).
class RatingBreakdownCard extends StatelessWidget {
  const RatingBreakdownCard({super.key, required this.average, required this.countLine, required this.breakdown});

  final String average;
  final String countLine;

  /// [1★ … 5★]
  final List<int> breakdown;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final most = breakdown.fold<int>(0, (a, b) => b > a ? b : a);
    final stars = double.tryParse(average)?.round() ?? 0;
    return Container(
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBaseTextWidget(average, style: text.display.copyWith(fontSize: 40, height: 1.1)),
              const SizedBox(height: 4),
              KnStars(rating: stars, size: 14),
              const SizedBox(height: 4),
              CustomBaseTextWidget(countLine, style: text.caption, color: kn.textSecondary),
            ],
          ),
          const SizedBox(width: KnSize.space16),
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Row(
                            children: [
                              CustomBaseTextWidget('$star', style: text.caption, color: kn.textSecondary),
                              const SizedBox(width: 2),
                              Icon(LucideIcons.star, size: 10, color: kn.textSecondary),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(KnSize.radiusFull),
                            child: Stack(
                              children: [
                                Container(height: 6, color: kn.bgSubtle),
                                FractionallySizedBox(
                                  widthFactor: most == 0 ? 0 : (breakdown[star - 1] / most).clamp(0.03, 1.0),
                                  child: Container(
                                    height: 6,
                                    color: breakdown[star - 1] == 0
                                        ? Colors.transparent
                                        : star <= 2
                                            ? kn.statusDanger
                                            : star == 3
                                                ? kn.borderStrong
                                                : kn.statusWarning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: KnSize.space8),
                        SizedBox(
                          width: 24,
                          child: CustomBaseTextWidget(
                            '${breakdown[star - 1]}',
                            style: text.caption,
                            color: kn.textSecondary,
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The technician's photo (or initials) and first name next to the stars.
class TechTag extends StatelessWidget {
  const TechTag({super.key, required this.person, this.light = false});

  final PersonRefModel person;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        KnInitialsAvatar(initials: TextUtils.initials(person.name), size: 22, url: person.avatarUrl, borderWidth: 0),
        const SizedBox(width: 6),
        Flexible(
          child: CustomBaseTextWidget(
            person.name,
            style: context.knText.labelSm,
            color: light ? KnPrimitive.cream400 : kn.textSecondary,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// A small coloured label ("Call me", "Came late").
class OfficePill extends StatelessWidget {
  const OfficePill({super.key, required this.label, this.icon, this.danger = false});

  final String label;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final fg = danger ? kn.statusDanger : kn.textPrimary;
    final mark = icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: danger ? kn.statusDangerBg : kn.bgSubtle,
        borderRadius: BorderRadius.circular(KnSize.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mark != null) ...[Icon(mark, size: 14, color: fg), const SizedBox(width: 4)],
          CustomBaseTextWidget(label, style: context.knText.labelSm, color: fg),
        ],
      ),
    );
  }
}

/// One review on M45: who and where, when, the stars and the technician, "Call me", the words,
/// the reply if there is one, and "Follow up" (low) or "Reply".
class OfficeReviewCard extends StatelessWidget {
  const OfficeReviewCard({
    super.key,
    required this.review,
    required this.ago,
    required this.open,
    required this.onTap,
    required this.onFollowUp,
    required this.onReply,
  });

  final CompanyReviewItemModel review;
  final String ago;

  /// A low review still waiting for follow-up.
  final bool open;
  final VoidCallback onTap;
  final VoidCallback onFollowUp;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final r = review;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    final words = r.comment?.trim();
    final tech = r.technician;
    final answer = r.reply;
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: ReviewWords.who(r),
      child: Ink(
        padding: const EdgeInsets.all(KnSize.space16),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: open ? kn.statusDanger : kn.borderDefault, width: open ? 1.5 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KnCoverImage(url: r.coverUrl, width: 40, height: 40, radius: KnSize.radiusMd, placeholderIcon: LucideIcons.wrench),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomBaseTextWidget(ReviewWords.who(r), style: text.label, maxLines: 1),
                      CustomBaseTextWidget(ReviewWords.where(r), style: text.caption, color: kn.textSecondary, maxLines: 1),
                    ],
                  ),
                ),
                const SizedBox(width: KnSize.space8),
                CustomBaseTextWidget(ago, style: text.caption, color: kn.textSecondary),
              ],
            ),
            const SizedBox(height: KnSize.space8),
            Row(
              children: [
                KnStars(rating: r.rating, size: 16),
                if (tech != null) ...[const SizedBox(width: KnSize.space8), Flexible(child: TechTag(person: tech))],
              ],
            ),
            if (r.wantsCallBack || r.followup?.status == 'resolved') ...[
              const SizedBox(height: KnSize.space8),
              Wrap(
                spacing: KnSize.space8,
                children: [
                  if (r.wantsCallBack && open) OfficePill(label: LangKeys.crevCallMe.tr, icon: LucideIcons.phone, danger: true),
                  if (r.followup?.status == 'resolved') OfficePill(label: LangKeys.crevResolved.tr, icon: LucideIcons.check),
                ],
              ),
            ],
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
                    if (answer.author != null)
                      CustomBaseTextWidget(answer.author!.name, style: text.captionStrong, color: kn.textSecondary),
                    const SizedBox(height: 2),
                    CustomBaseTextWidget(answer.text, style: text.caption, maxLines: 3),
                  ],
                ),
              ),
            ],
            if (open) ...[
              const SizedBox(height: KnSize.space12),
              KnCustomButton(
                key: ValueKey('follow-up-${r.id}'),
                text: LangKeys.crevFollowUp.tr,
                icon: LucideIcons.phone,
                onTap: onFollowUp,
              ),
            ] else if (r.needsReply) ...[
              const SizedBox(height: KnSize.space12),
              IntrinsicWidth(
                child: KnCustomButton(
                  key: ValueKey('reply-${r.id}'),
                  text: LangKeys.crevReply.tr,
                  icon: LucideIcons.messageSquare,
                  variant: KnButtonVariant.secondary,
                  small: true,
                  onTap: onReply,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
