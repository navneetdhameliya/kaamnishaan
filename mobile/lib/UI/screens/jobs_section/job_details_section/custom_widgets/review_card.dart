import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../../infrastructure/shared/review_words.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_stars.dart';
import '../../../../common_widgets/kn_text_link.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// The "Customer review" card on a job (M15, Figma 273:2426 to 273:2748): not asked, queued, link sent,
/// rated, opted out.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.words,
    required this.onRequest,
    required this.onCancel,
    required this.onOpen,
    this.busy = false,
  });

  final JobReviewModel review;
  final ReviewWords words;
  final VoidCallback onRequest;
  final VoidCallback onCancel;
  final VoidCallback onOpen;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final (chipBg, chipFg, chipIcon) = switch (review.status) {
      'queued' => (kn.statusWarningBg, kn.statusWarning, LucideIcons.clock),
      'rated' => (kn.statusSuccessBg, kn.statusSuccess, LucideIcons.check),
      'opted_out' => (kn.statusOfflineBg, kn.statusOffline, LucideIcons.lock),
      _ => (kn.bgSubtle, kn.textSecondary, null),
    };
    return Container(
      key: const ValueKey('review-card'),
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
              Expanded(child: CustomBaseTextWidget(LangKeys.reviewTitle.tr, style: text.label)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (chipIcon != null) ...[
                      Icon(chipIcon, size: 14, color: chipFg),
                      const SizedBox(width: 6),
                    ],
                    CustomBaseTextWidget(words.chip(review), style: text.labelSm, color: chipFg),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KnSize.space12),
          ..._body(context),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    switch (review.status) {
      case 'not_requested':
        return [
          CustomBaseTextWidget(words.notAskedBody(review), style: text.body, color: kn.textSecondary),
          if (review.canRequest) ...[
            const SizedBox(height: KnSize.space16),
            Align(
              alignment: Alignment.centerLeft,
              child: KnCustomButton(
                key: const ValueKey('review-request'),
                text: LangKeys.reviewRequest.tr,
                icon: LucideIcons.sparkles,
                loading: busy,
                onTap: onRequest,
              ),
            ),
          ],
        ];
      case 'queued':
        return [
          _Banner(icon: LucideIcons.clock, text: LangKeys.reviewQueuedBody.tr, bg: kn.statusWarningBg, fg: kn.statusWarning),
          if (review.canCancel ?? false) ...[
            const SizedBox(height: KnSize.space12),
            KnTextLink(key: const ValueKey('review-cancel'), text: LangKeys.reviewCancel.tr, onTap: onCancel),
          ],
        ];
      case 'rated':
        final b = review.review;
        if (b == null) return const [];
        return [
          Row(
            children: [
              KnStars(rating: b.technicianRating ?? b.rating, size: 20),
              const SizedBox(width: KnSize.space8),
              Flexible(
                child: CustomBaseTextWidget(
                  words.ratedLine(b),
                  style: text.captionStrong,
                  color: kn.textSecondary,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          if ((b.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: KnSize.space8),
            CustomBaseTextWidget('“${b.comment}”', style: text.bodyLg, maxLines: 4),
          ],
          const SizedBox(height: KnSize.space8),
          CustomInkWell(
            key: const ValueKey('review-open'),
            onTap: onOpen,
            borderRadius: BorderRadius.circular(KnSize.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: CustomBaseTextWidget(LangKeys.reviewOpen.tr, style: text.labelSm, color: kn.textLink)),
                  Icon(LucideIcons.chevronRight, size: 18, color: kn.textLink),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          CustomBaseTextWidget(LangKeys.reviewAllStopped.tr, style: text.caption, color: kn.textSecondary),
        ];
      case 'opted_out':
        return [
          _Banner(icon: LucideIcons.lock, text: LangKeys.reviewOptedOutBody.tr, bg: kn.bgSubtle, fg: kn.textSecondary),
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(words.optedOutLine(review), style: text.caption, color: kn.textSecondary),
        ];
      case 'stopped' || 'paused_no_credits':
        return [CustomBaseTextWidget(LangKeys.reviewStoppedBody.tr, style: text.body, color: kn.textSecondary)];
      default: // link sent, reminded, AI call
        final reminder = words.reminderLine(review);
        final call = words.aiCallLine(review);
        return [
          _Step(done: true, title: LangKeys.reviewLinkSent.tr, line: words.sentLine(review)),
          if (reminder != null)
            _Step(
              done: const {'reminded', 'ai_call_scheduled', 'ai_call_done'}.contains(review.status),
              title: LangKeys.reviewReminder.tr,
              line: reminder,
            ),
          if (call != null)
            _Step(done: review.status == 'ai_call_done', title: LangKeys.reviewAiCall.tr, line: call),
          const SizedBox(height: 4),
          CustomBaseTextWidget(words.requestedBy(review), style: text.caption, color: kn.textSecondary),
        ];
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.bg, required this.fg});

  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 18, color: fg)),
          const SizedBox(width: KnSize.space12),
          Expanded(child: CustomBaseTextWidget(text, style: context.knText.labelSm, color: fg)),
        ],
      ),
    );
  }
}

/// One step of the follow-up: a green tick when done, a clock when planned.
class _Step extends StatelessWidget {
  const _Step({required this.done, required this.title, required this.line});

  final bool done;
  final String title;
  final String line;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Padding(
      padding: const EdgeInsets.only(bottom: KnSize.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(shape: BoxShape.circle, color: done ? kn.statusSuccess : kn.bgSubtle),
            child: Icon(
              done ? LucideIcons.check : LucideIcons.clock,
              size: 14,
              color: done ? kn.textOnAction : kn.textSecondary,
            ),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(title, style: text.label, color: done ? kn.textPrimary : kn.textSecondary),
                if (line.isNotEmpty) CustomBaseTextWidget(line, style: text.caption, color: kn.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
