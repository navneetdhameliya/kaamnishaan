import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_stars.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../../customer_section/customer_details_section/custom_widgets/customer_parts.dart';
import 'custom_widgets/review_tile.dart';
import 'my_reviews_controller.dart';

/// M44 My reviews (Figma 265:2327; empty 288:2781).
class MyReviewsScreen extends GetView<MyReviewsController> {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kn.bgCanvas,
        body: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: Obx(() {
              final empty = controller.empty;
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  // the dark header with the average
                  Container(
                    decoration: const BoxDecoration(
                      color: KnPrimitive.mocha900,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned(
                          right: -80,
                          top: -70,
                          child: Container(
                            width: 230,
                            height: 230,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: KnPrimitive.cream100.withValues(alpha: 0.10), width: 30),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(KnSize.space16, top + 12, KnSize.space16, KnSize.space24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  HeaderButton(
                                    key: const ValueKey('my-reviews-back'),
                                    icon: LucideIcons.chevronLeft,
                                    label: MaterialLocalizations.of(context).backButtonTooltip,
                                    onTap: Get.back,
                                  ),
                                  const SizedBox(width: KnSize.space12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CustomBaseTextWidget(LangKeys.meMyReviews.tr, style: text.h3, color: KnPrimitive.cream50),
                                        CustomBaseTextWidget(
                                          LangKeys.myrevSubtitle.tr,
                                          style: text.caption,
                                          color: KnPrimitive.cream400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: KnSize.space24),
                              if (controller.loading.value)
                                const SizedBox(height: 64)
                              else if (empty)
                                Row(
                                  children: [
                                    Container(width: 36, height: 3, color: KnPrimitive.cream50),
                                    const SizedBox(width: KnSize.space16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CustomBaseTextWidget(LangKeys.myrevEmptyHead.tr, style: text.label, color: KnPrimitive.cream50),
                                          CustomBaseTextWidget(
                                            LangKeys.myrevEmptySub.tr,
                                            style: text.caption,
                                            color: KnPrimitive.cream400,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else ...[
                                Row(
                                  children: [
                                    CustomBaseTextWidget(
                                      controller.average,
                                      style: text.display.copyWith(fontSize: 40, height: 1.1),
                                      color: KnPrimitive.cream50,
                                    ),
                                    const SizedBox(width: KnSize.space16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          KnStars(rating: controller.stars, size: 16, onDark: true),
                                          const SizedBox(height: 4),
                                          CustomBaseTextWidget(
                                            controller.summary,
                                            style: text.captionStrong,
                                            color: KnPrimitive.cream400,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: KnSize.space12),
                                Wrap(
                                  spacing: KnSize.space8,
                                  runSpacing: KnSize.space8,
                                  children: [
                                    for (final t in controller.tags)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: KnPrimitive.cream100.withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(KnSize.radiusFull),
                                        ),
                                        child: CustomBaseTextWidget(t, style: text.labelSm, color: KnPrimitive.cream50),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(KnSize.space16, KnSize.space16, KnSize.space16, KnSize.space24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (controller.loading.value)
                          for (var i = 0; i < 2; i++) ...const [
                            CommonShimmer(height: 150, radius: KnSize.radiusLg),
                            SizedBox(height: KnSize.space12),
                          ]
                        else if (empty)
                          const _Empty()
                        else
                          for (final r in controller.items) ...[
                            ReviewTile(
                              key: ValueKey('review-${r.id}'),
                              name: controller.who(r),
                              meta: controller.meta(r),
                              ago: controller.ago(r),
                              rating: controller.rating(r),
                              coverUrl: r.coverUrl,
                              comment: r.comment,
                              repliedBy: controller.replied(r),
                              reply: r.reply?.text,
                              onTap: () => controller.onReviewTap(r),
                            ),
                            const SizedBox(height: KnSize.space12),
                          ],
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Empty extends GetView<MyReviewsController> {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Column(
      children: [
        const SizedBox(height: KnSize.space24),
        Container(
          width: 40,
          height: 80,
          decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(20)),
          child: Icon(LucideIcons.sparkles, size: 24, color: kn.textSecondary),
        ),
        const SizedBox(height: KnSize.space16),
        CustomBaseTextWidget(LangKeys.myrevEmptyTitle.tr, style: text.h2, textAlign: TextAlign.center),
        const SizedBox(height: KnSize.space8),
        CustomBaseTextWidget(LangKeys.myrevEmptyBody.tr, style: text.body, color: kn.textSecondary, textAlign: TextAlign.center),
        const SizedBox(height: KnSize.space16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(KnSize.space12),
          decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.camera, size: 18, color: kn.textSecondary),
              const SizedBox(width: KnSize.space8),
              Expanded(child: CustomBaseTextWidget(LangKeys.myrevTip.tr, style: text.labelSm, color: kn.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: KnSize.space16),
        Align(
          alignment: Alignment.centerLeft,
          child: IntrinsicWidth(
            child: KnCustomButton(
              key: const ValueKey('my-reviews-see-jobs'),
              text: LangKeys.myrevSeeJobs.tr,
              icon: LucideIcons.briefcase,
              variant: KnButtonVariant.secondary,
              onTap: controller.onSeeJobsTap,
            ),
          ),
        ),
      ],
    );
  }
}
