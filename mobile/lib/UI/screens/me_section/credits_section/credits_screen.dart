import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'credits_controller.dart';

/// M41 Follow-up credits (Figma 282:2656).
class CreditsScreen extends GetView<CreditsController> {
  const CreditsScreen({super.key});

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
              final d = controller.data.value;
              final bought = controller.boughtLine;
              return ListView(
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
                children: [
                  KnTitleBar(title: LangKeys.billCredits.tr, subtitle: controller.subtitle),
                  const SizedBox(height: KnSize.space16),
                  if (d == null)
                    const CommonShimmer(height: 200, radius: KnSize.radiusLg)
                  else ...[
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CustomBaseTextWidget(
                                controller.balance,
                                style: text.display.copyWith(fontSize: 40, height: 1.1),
                                color: controller.empty ? kn.statusDanger : kn.textPrimary,
                              ),
                              const SizedBox(width: KnSize.space8),
                              Expanded(
                                child: CustomBaseTextWidget(controller.leftLabel, style: text.labelSm, color: kn.textSecondary),
                              ),
                            ],
                          ),
                          if (!controller.noLimit) ...[
                            const SizedBox(height: KnSize.space12),
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
                          ],
                          if (bought != null) ...[
                            const SizedBox(height: KnSize.space8),
                            CustomBaseTextWidget(bought, style: text.caption, color: kn.textSecondary),
                          ],
                          const SizedBox(height: KnSize.space12),
                          _UseRow(label: LangKeys.credReminders.tr, value: controller.remindersValue),
                          _UseRow(label: controller.callsLabel, value: controller.callsValue),
                          _UseRow(label: LangKeys.credEmails.tr, value: LangKeys.credFree.tr),
                        ],
                      ),
                    ),
                    const SizedBox(height: KnSize.space12),
                    Container(
                      padding: const EdgeInsets.all(KnSize.space12),
                      decoration: BoxDecoration(
                        color: kn.statusWarningBg,
                        borderRadius: BorderRadius.circular(KnSize.radiusMd),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(LucideIcons.circleAlert, size: 18, color: kn.statusWarning),
                          const SizedBox(width: KnSize.space8),
                          Expanded(
                            child: CustomBaseTextWidget(LangKeys.credWarning.tr, style: text.labelSm, color: kn.statusWarning),
                          ),
                        ],
                      ),
                    ),
                    if (controller.packs.isNotEmpty) ...[
                      const SizedBox(height: KnSize.space16),
                      CustomBaseTextWidget(LangKeys.credTopUp.tr, style: text.label),
                      const SizedBox(height: KnSize.space8),
                      for (final p in controller.packs) ...[
                        _PackCard(
                          key: ValueKey('pack-${p.credits}'),
                          title: controller.packTitle(p),
                          hint: controller.packHint(p),
                          price: controller.price(p),
                          selected: controller.picked.value == p.id,
                          onTap: () => controller.onPick(p.id),
                        ),
                        const SizedBox(height: KnSize.space8),
                      ],
                      CustomBaseTextWidget(LangKeys.credBuySoon.tr, style: text.caption, color: kn.textSecondary),
                    ],
                  ],
                ],
              );
            }),
          ),
        ),
      ),
      bottomNavigationBar: Obx(
        () => controller.packs.isEmpty
            ? const SizedBox.shrink()
            : KnScreenFooter(
                children: [
                  KnCustomButton(
                    key: const ValueKey('credits-buy'),
                    text: controller.buyLabel,
                    icon: LucideIcons.plus,
                    enabled: controller.paymentsReady,
                    onDisabledTap: controller.onBuyTap,
                    onTap: controller.onBuyTap,
                  ),
                ],
              ),
      ),
    );
  }
}

class _UseRow extends StatelessWidget {
  const _UseRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: CustomBaseTextWidget(label, style: context.knText.caption, color: kn.textSecondary)),
          CustomBaseTextWidget(value, style: context.knText.captionStrong),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    super.key,
    required this.title,
    required this.hint,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String hint;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: title,
      child: Ink(
        padding: const EdgeInsets.all(KnSize.space16),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: selected ? kn.textPrimary : kn.borderDefault, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kn.textPrimary, width: 2)),
              child: selected
                  ? Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: kn.textPrimary))
                  : null,
            ),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(title, style: text.label),
                  CustomBaseTextWidget(hint, style: text.caption, color: kn.textSecondary),
                ],
              ),
            ),
            const SizedBox(width: KnSize.space8),
            CustomBaseTextWidget(price, style: text.h3),
          ],
        ),
      ),
    );
  }
}
