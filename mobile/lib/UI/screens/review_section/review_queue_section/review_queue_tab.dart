import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/queue_card.dart';
import 'review_queue_controller.dart';

/// M30 Reports for owners and managers (Figma 46:1204).
class ReviewQueueTab extends GetView<ReviewQueueController> {
  const ReviewQueueTab({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: controller.load,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: Obx(
            () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, 120),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(LangKeys.navReports.tr, style: text.h1),
                          CustomBaseTextWidget(controller.subtitle, style: text.caption, color: kn.textSecondary),
                        ],
                      ),
                    ),
                    CustomInkWell(
                      key: const ValueKey('queue-search'),
                      onTap: controller.onSearchTap,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kn.bgSurface,
                          border: Border.all(color: kn.borderDefault),
                        ),
                        child: Icon(
                          controller.searching.value ? LucideIcons.x : LucideIcons.search,
                          size: 20,
                          color: kn.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (controller.searching.value) ...[
                  const SizedBox(height: KnSize.space12),
                  TextField(
                    key: const ValueKey('queue-search-field'),
                    controller: controller.search,
                    autofocus: true,
                    onChanged: controller.onSearchChanged,
                    style: text.body,
                    decoration: InputDecoration(
                      hintText: LangKeys.queueSearchHint.tr,
                      prefixIcon: Icon(LucideIcons.search, size: 18, color: kn.textSecondary),
                      filled: true,
                      fillColor: kn.bgSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(KnSize.radiusFull),
                        borderSide: BorderSide(color: kn.borderDefault),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(KnSize.radiusFull),
                        borderSide: BorderSide(color: kn.borderDefault),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: KnSize.space16),
                _Tabs(controller: controller),
                const SizedBox(height: KnSize.space16),
                if (!controller.loaded.value) ...const [
                  CommonShimmer(height: 170, radius: KnSize.radiusLg),
                  SizedBox(height: KnSize.space12),
                  CommonShimmer(height: 170, radius: KnSize.radiusLg),
                ] else if (controller.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40, bottom: 24),
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusSuccessBg),
                          child: Icon(LucideIcons.check, size: 36, color: kn.statusSuccess),
                        ),
                        const SizedBox(height: KnSize.space16),
                        CustomBaseTextWidget(LangKeys.queueEmpty.tr, style: text.h3, textAlign: TextAlign.center),
                        const SizedBox(height: KnSize.space4),
                        CustomBaseTextWidget(
                          LangKeys.queueEmptyBody.tr,
                          style: text.body,
                          color: kn.textSecondary,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  for (final r in controller.items) ...[
                    QueueCard(
                      key: ValueKey('queue-${r.id}'),
                      report: r,
                      meta: controller.meta(r),
                      byLine: controller.byLine(r),
                      waitChip: controller.waitChip(r),
                      oldest: controller.isOldest(r),
                      onTap: () => controller.onOpen(r),
                    ),
                    const SizedBox(height: KnSize.space12),
                  ],
                if (controller.tab.value == QueueTab.review && controller.approvedWeek.value > 0)
                  CustomInkWell(
                    key: const ValueKey('queue-approved-card'),
                    onTap: controller.onApprovedCardTap,
                    borderRadius: BorderRadius.circular(KnSize.radiusLg),
                    child: Container(
                      padding: const EdgeInsets.all(KnSize.space16),
                      decoration: BoxDecoration(
                        color: kn.actionSecondary,
                        borderRadius: BorderRadius.circular(KnSize.radiusLg),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusSuccessBg),
                            child: Icon(LucideIcons.check, size: 20, color: kn.statusSuccess),
                          ),
                          const SizedBox(width: KnSize.space12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomBaseTextWidget(
                                  LangKeys.queueApprovedWeek.trParams({'n': '${controller.approvedWeek.value}'}),
                                  style: text.label,
                                ),
                                CustomBaseTextWidget(
                                  LangKeys.queueApprovedWeekBody.tr,
                                  style: text.caption,
                                  color: kn.textSecondary,
                                ),
                              ],
                            ),
                          ),
                          Icon(LucideIcons.chevronRight, size: 20, color: kn.textSecondary),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "To review 2 · Approved · Changes".
class _Tabs extends StatelessWidget {
  const _Tabs({required this.controller});

  final ReviewQueueController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
      child: Row(
        children: [
          for (final t in QueueTab.values)
            Expanded(
              child: CustomInkWell(
                key: ValueKey('queue-tab-${t.name}'),
                onTap: () => controller.onTabTap(t),
                borderRadius: BorderRadius.circular(KnSize.radiusFull),
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: controller.tab.value == t ? kn.bgSurface : null,
                    borderRadius: BorderRadius.circular(KnSize.radiusFull),
                    boxShadow: controller.tab.value == t ? KnShadow.sm : null,
                  ),
                  child: CustomBaseTextWidget(
                    controller.tabLabel(t),
                    style: text.label,
                    color: controller.tab.value == t ? kn.textPrimary : kn.textSecondary,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
