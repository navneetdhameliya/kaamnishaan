import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'plan_limit_controller.dart';

/// M41 Plan limit reached (Figma 248:2573).
class PlanLimitScreen extends GetView<PlanLimitController> {
  const PlanLimitScreen({super.key});

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
          child: Obx(() {
            final d = controller.data.value;
            return ListView(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: KnBackButton(icon: LucideIcons.x, onTap: controller.onLaterTap),
                ),
                const SizedBox(height: KnSize.space16),
                Center(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(color: kn.statusWarningBg, shape: BoxShape.circle),
                    child: Icon(LucideIcons.fileText, size: 40, color: kn.statusWarning),
                  ),
                ),
                const SizedBox(height: KnSize.space24),
                if (d == null)
                  const CommonShimmer(height: 220, radius: KnSize.radiusLg)
                else ...[
                  CustomBaseTextWidget(controller.title, style: text.h1, textAlign: TextAlign.center),
                  const SizedBox(height: KnSize.space12),
                  CustomBaseTextWidget(controller.body, style: text.bodyLg, color: kn.textSecondary, textAlign: TextAlign.center),
                  const SizedBox(height: KnSize.space16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KnSize.radiusFull),
                    child: Stack(
                      children: [
                        Container(height: 8, color: kn.actionSecondary),
                        FractionallySizedBox(
                          widthFactor: controller.fraction,
                          child: Container(height: 8, color: kn.statusWarning),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KnSize.space8),
                  CustomBaseTextWidget(controller.resets, style: text.caption, color: kn.textSecondary, textAlign: TextAlign.center),
                  const SizedBox(height: KnSize.space16),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _PlanCard(plan: d.plan, controller: controller, current: true)),
                        if (d.upgrade != null) ...[
                          const SizedBox(width: KnSize.space12),
                          Expanded(child: _PlanCard(plan: d.upgrade!, controller: controller, current: false)),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
      ),
      bottomNavigationBar: Obx(() {
        final d = controller.data.value;
        if (d == null) return const SizedBox.shrink();
        return KnScreenFooter(
          children: [
            if (controller.canUpgrade && d.upgrade != null)
              Align(
                alignment: Alignment.centerLeft,
                child: IntrinsicWidth(
                  child: KnCustomButton(
                    key: const ValueKey('plan-limit-upgrade'),
                    text: controller.upgradeLabel,
                    icon: LucideIcons.sparkles,
                    onTap: controller.onUpgradeTap,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: IntrinsicWidth(
                child: KnCustomButton(
                  key: const ValueKey('plan-limit-later'),
                  text: controller.canUpgrade ? LangKeys.plLater.tr : LangKeys.plOk.tr,
                  variant: controller.canUpgrade ? KnButtonVariant.secondary : KnButtonVariant.primary,
                  onTap: controller.onLaterTap,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.controller, required this.current});

  final PlanOutModel plan;
  final PlanLimitController controller;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: current ? kn.borderDefault : kn.textPrimary, width: current ? 1 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!current) ...[
            _Chip(label: LangKeys.plRecommended.tr),
            const SizedBox(height: KnSize.space8),
          ],
          CustomBaseTextWidget(plan.name, style: text.label),
          const SizedBox(height: 4),
          CustomBaseTextWidget(controller.price(plan), style: text.h2),
          const SizedBox(height: 4),
          CustomBaseTextWidget(controller.limits(plan), style: text.caption, color: kn.textSecondary),
          if (current) ...[
            const SizedBox(height: KnSize.space8),
            _Chip(label: LangKeys.plCurrent.tr),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: context.kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
      child: CustomBaseTextWidget(label, style: context.knText.labelSm),
    );
  }
}
