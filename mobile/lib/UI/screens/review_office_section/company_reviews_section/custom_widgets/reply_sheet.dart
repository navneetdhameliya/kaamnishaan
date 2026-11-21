import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_dictation.dart';
import '../../../../common_widgets/kn_stars.dart';
import '../../../../common_widgets/kn_text_box.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../company_reviews_controller.dart';

/// M45 Reply to review (Figma 265:4461): the review, "Suggest a reply", the reply, who sees it, Send.
class ReplySheet extends StatelessWidget {
  const ReplySheet({super.key, required this.controller, required this.review});

  final CompanyReviewsController controller;
  final CompanyReviewItemModel review;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final quote = controller.quote(review);
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KnSize.space12),
            decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KnStars(rating: review.rating, size: 14),
                if (quote != null) ...[
                  const SizedBox(height: 4),
                  CustomBaseTextWidget('"$quote"', style: text.caption, maxLines: 3),
                ],
              ],
            ),
          ),
          const SizedBox(height: KnSize.space12),
          Obx(
            () => CustomInkWell(
              key: const ValueKey('reply-suggest'),
              onTap: () => controller.onSuggest(review),
              borderRadius: BorderRadius.circular(KnSize.radiusFull),
              semanticLabel: LangKeys.crevSuggest.tr,
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: KnSize.space8),
                decoration: BoxDecoration(color: kn.statusSuccessBg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    controller.suggesting.value
                        ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(LucideIcons.sparkles, size: 14, color: kn.statusSuccess),
                    const SizedBox(width: 6),
                    CustomBaseTextWidget(LangKeys.crevSuggest.tr, style: text.labelSm),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: KnSize.space12),
          KnTextBox(
            fieldKey: const ValueKey('reply-text'),
            controller: controller.replyText,
            hint: LangKeys.crevReplyHint.tr,
            suffix: KnMicButton(key: const ValueKey('reply-mic'), dictation: controller.dictation, box: controller.replyText),
          ),
          KnDictationNote(dictation: controller.dictation, box: controller.replyText),
          const SizedBox(height: KnSize.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.globe, size: 16, color: kn.textSecondary),
              const SizedBox(width: KnSize.space8),
              Expanded(
                child: CustomBaseTextWidget(controller.replyNote(review), style: text.caption, color: kn.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: KnSize.space16),
          Obx(
            () => IntrinsicWidth(
              child: KnCustomButton(
                key: const ValueKey('reply-send'),
                text: LangKeys.crevSendReply.tr,
                icon: LucideIcons.send,
                loading: controller.sending.value,
                enabled: controller.draft.value.trim().isNotEmpty,
                onTap: () async {
                  if (await controller.onSendReply(review)) Get.back<void>();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
