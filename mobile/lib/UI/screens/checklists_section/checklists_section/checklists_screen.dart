import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'checklists_controller.dart';
import 'custom_widgets/checklist_cards.dart';

/// M24 Checklists (Figma 26:1327).
class ChecklistsScreen extends GetView<ChecklistsController> {
  const ChecklistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: Obx(
        () => controller.active == null
            ? const SizedBox.shrink()
            : KnScreenFooter(
                children: [
                  KnCustomButton(
                    key: const ValueKey('start-checklist'),
                    text: controller.startLabel,
                    icon: LucideIcons.play,
                    onTap: controller.onStartTap,
                  ),
                ],
              ),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                Row(
                  children: [
                    const KnBackButton(),
                    const SizedBox(width: KnSize.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(LangKeys.checklistTitle.tr, style: text.h3),
                          Obx(
                            () => CustomBaseTextWidget(
                              LangKeys.checklistCount.trParams({
                                'customer': controller.args.customer,
                                'count': '${controller.lists.length}',
                              }),
                              style: text.caption,
                              color: kn.textSecondary,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KnSize.space16),
                Obx(() => _lists(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lists(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    if (!controller.loaded.value) {
      return const Column(
        children: [
          CommonShimmer(height: 228, radius: KnSize.radiusLg),
          SizedBox(height: 12),
          CommonShimmer(height: 74, radius: KnSize.radiusLg),
        ],
      );
    }
    if (controller.lists.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 48),
        child: CustomBaseTextWidget(
          LangKeys.checklistNone.tr,
          style: text.bodyLg,
          color: kn.textSecondary,
          textAlign: TextAlign.center,
        ),
      );
    }
    final active = controller.active;
    final ordered = [?active, ...controller.lists.where((c) => c.id != active?.id)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in ordered) ...[
          if (c != ordered.first) const SizedBox(height: KnSize.space12),
          if (c.id == active?.id)
            ActiveChecklistCard(
              key: ValueKey('checklist-${c.id}'),
              name: c.name,
              meta: controller.meta(c),
              answered: controller.answeredOf(c),
              total: c.total,
              coverUrl: controller.args.coverUrl,
              equipment: controller.args.equipment,
              onTap: () => controller.open(c),
            )
          else
            ChecklistRowCard(
              key: ValueKey('checklist-${c.id}'),
              name: c.name,
              line: controller.isDone(c) ? controller.doneLine(c) : controller.meta(c),
              done: controller.isDone(c),
              onTap: () => controller.open(c),
            ),
        ],
        const SizedBox(height: KnSize.space16),
        Row(
          children: [
            Icon(LucideIcons.volume2, size: 16, color: kn.textSecondary),
            const SizedBox(width: KnSize.space8),
            Expanded(
              child: CustomBaseTextWidget(LangKeys.checklistReadAloud.tr, style: text.caption, color: kn.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
