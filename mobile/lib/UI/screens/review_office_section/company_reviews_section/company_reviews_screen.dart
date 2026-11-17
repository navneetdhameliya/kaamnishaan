import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../../jobs_section/job_list_section/custom_widgets/job_list_parts.dart';
import '../../me_section/me_section/custom_widgets/me_rows.dart';
import 'company_reviews_controller.dart';
import 'custom_widgets/reply_sheet.dart';
import 'custom_widgets/review_office_parts.dart';

/// M45 Customer reviews (Figma 265:4242; empty 288:5136; loading 288:5228).
class CompanyReviewsScreen extends GetView<CompanyReviewsController> {
  const CompanyReviewsScreen({super.key});

  void _more() {
    showKnBottomSheet<void>(
      title: LangKeys.crevMore.tr,
      child: MeCard(
        rows: [
          MeRow(
            key: const ValueKey('reviews-requests'),
            icon: LucideIcons.send,
            label: LangKeys.crevRequests.tr,
            onTap: () {
              Get.back<void>();
              controller.onRequestsTap();
            },
          ),
          MeRow(
            key: const ValueKey('reviews-settings'),
            icon: LucideIcons.settings,
            label: LangKeys.crevSettings.tr,
            onTap: () {
              Get.back<void>();
              controller.onSettingsTap();
            },
          ),
          MeRow(
            key: const ValueKey('reviews-followups'),
            icon: LucideIcons.calendarClock,
            label: LangKeys.crevFollowups.tr,
            onTap: () {
              Get.back<void>();
              controller.onFollowupsTap();
            },
          ),
          MeRow(
            key: const ValueKey('reviews-credits'),
            icon: LucideIcons.coins,
            label: LangKeys.billCredits.tr,
            onTap: () {
              Get.back<void>();
              controller.onCreditsTap();
            },
          ),
        ],
      ),
    );
  }

  void _reply(CompanyReviewItemModel r) {
    controller.startReply(r);
    showKnBottomSheet<void>(
      title: LangKeys.crevReplyTo.trParams({'name': r.reviewerName ?? r.customer}),
      child: ReplySheet(controller: controller, review: r),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: Obx(() {
              final page = controller.page.value;
              return ListView(
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
                children: [
                  Row(
                    children: [
                      const KnBackButton(),
                      const SizedBox(width: KnSize.space12),
                      Expanded(child: CustomBaseTextWidget(LangKeys.crevTitle.tr, style: text.h2, maxLines: 1)),
                      const SizedBox(width: KnSize.space12),
                      OfficeRoundButton(
                        key: const ValueKey('reviews-more'),
                        icon: LucideIcons.slidersHorizontal,
                        label: LangKeys.crevMore.tr,
                        onTap: _more,
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space16),
                  if (controller.loading.value && page == null) ...[
                    const CommonShimmer(height: 132, radius: KnSize.radiusLg),
                    const SizedBox(height: KnSize.space12),
                    for (var i = 0; i < 3; i++) ...[
                      const CommonShimmer(height: 150, radius: KnSize.radiusLg),
                      const SizedBox(height: KnSize.space12),
                    ],
                  ] else if (controller.empty)
                    _Empty(title: LangKeys.crevEmpty.tr, body: LangKeys.crevEmptyBody.tr)
                  else ...[
                    RatingBreakdownCard(
                      average: controller.average,
                      countLine: controller.countLine,
                      breakdown: controller.breakdown,
                    ),
                    const SizedBox(height: KnSize.space12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final f in CompanyReviewsController.filters) ...[
                            JobFilterChip(
                              key: ValueKey('reviews-filter-$f'),
                              label: controller.chip(f),
                              selected: controller.filter.value == f,
                              onTap: () => controller.onFilter(f),
                            ),
                            const SizedBox(width: KnSize.space8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: KnSize.space12),
                    if (controller.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: KnSize.space24),
                        child: CustomBaseTextWidget(
                          LangKeys.crevNoneHere.tr,
                          style: text.body,
                          color: kn.textSecondary,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    for (final r in controller.items) ...[
                      OfficeReviewCard(
                        key: ValueKey('review-${r.id}'),
                        review: r,
                        ago: controller.ago(r),
                        open: controller.open(r),
                        onTap: () => controller.onCardTap(r),
                        onFollowUp: () => controller.onFollowUpTap(r),
                        onReply: () => _reply(r),
                      ),
                      const SizedBox(height: KnSize.space12),
                    ],
                  ],
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: KnSize.space16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
            child: Icon(LucideIcons.star, size: 28, color: kn.textSecondary),
          ),
          const SizedBox(height: KnSize.space16),
          CustomBaseTextWidget(title, style: context.knText.h3, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          CustomBaseTextWidget(body, style: context.knText.body, color: kn.textSecondary, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
