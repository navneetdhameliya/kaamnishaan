import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../../customer_section/customer_details_section/custom_widgets/customer_parts.dart';
import 'billing_controller.dart';

/// M41 Plan and billing (Figma 248:2475).
class BillingScreen extends GetView<BillingController> {
  const BillingScreen({super.key});

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
              final b = controller.data.value;
              final up = controller.upgrade;
              return ListView(
                padding: EdgeInsets.zero,
                children: [
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
                          padding: EdgeInsets.fromLTRB(KnSize.space16, top + 12, KnSize.space16, 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  HeaderButton(
                                    key: const ValueKey('billing-back'),
                                    icon: LucideIcons.chevronLeft,
                                    label: MaterialLocalizations.of(context).backButtonTooltip,
                                    onTap: Get.back,
                                  ),
                                  const SizedBox(width: KnSize.space12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CustomBaseTextWidget(LangKeys.billTitle.tr, style: text.h3, color: KnPrimitive.cream50),
                                        CustomBaseTextWidget(
                                          LangKeys.billOwnerOnly.tr,
                                          style: text.caption,
                                          color: KnPrimitive.cream400,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: KnSize.space16),
                              if (b == null)
                                const SizedBox(height: 90)
                              else ...[
                                Wrap(
                                  spacing: KnSize.space8,
                                  runSpacing: KnSize.space8,
                                  children: [
                                    _HeaderChip(label: controller.planName),
                                    _HeaderChip(label: controller.periodChip, icon: LucideIcons.clock),
                                  ],
                                ),
                                const SizedBox(height: KnSize.space8),
                                CustomBaseTextWidget(
                                  controller.price,
                                  style: text.display.copyWith(fontSize: 36, height: 1.15),
                                  color: KnPrimitive.cream50,
                                ),
                                CustomBaseTextWidget(controller.company, style: text.captionStrong, color: KnPrimitive.cream400),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (b == null)
                            const CommonShimmer(height: 220, radius: KnSize.radiusLg)
                          else
                            Container(
                              padding: const EdgeInsets.all(KnSize.space16),
                              decoration: BoxDecoration(
                                color: kn.bgSurface,
                                borderRadius: BorderRadius.circular(KnSize.radiusLg),
                                border: Border.all(color: kn.borderDefault),
                                boxShadow: KnShadow.md,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomBaseTextWidget(LangKeys.billThisMonth.tr, style: text.label),
                                  const SizedBox(height: KnSize.space12),
                                  for (var i = 0; i < controller.usage.length; i += 2) ...[
                                    if (i > 0) const SizedBox(height: KnSize.space8),
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          for (var j = i; j < i + 2; j++) ...[
                                            if (j > i) const SizedBox(width: KnSize.space8),
                                            Expanded(
                                              child: j < controller.usage.length
                                                  ? _UsageTile(
                                                      key: ValueKey('usage-${controller.usage[j].key}'),
                                                      view: controller.usage[j],
                                                      onTap: () => controller.onUsageTap(controller.usage[j]),
                                                    )
                                                  : const SizedBox.shrink(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          if (up != null) ...[
                            const SizedBox(height: KnSize.space16),
                            Container(
                              padding: const EdgeInsets.all(KnSize.space16),
                              decoration: BoxDecoration(
                                color: kn.bgSurface,
                                borderRadius: BorderRadius.circular(KnSize.radiusLg),
                                border: Border.all(color: kn.textPrimary, width: 1.5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: KnSize.space8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      CustomBaseTextWidget(up.name, style: text.h3),
                                      if (up.mostPopular)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: kn.actionSecondary,
                                            borderRadius: BorderRadius.circular(KnSize.radiusFull),
                                          ),
                                          child: CustomBaseTextWidget(LangKeys.billMostPopular.tr, style: text.labelSm),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  CustomBaseTextWidget(controller.upgradeLine(up), style: text.body, color: kn.textSecondary),
                                  const SizedBox(height: KnSize.space12),
                                  IntrinsicWidth(
                                    child: KnCustomButton(
                                      key: const ValueKey('billing-upgrade'),
                                      text: LangKeys.billUpgrade.trParams({'name': up.name}),
                                      icon: LucideIcons.sparkles,
                                      onTap: controller.onUpgradeTap,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (b != null) ...[
                            const SizedBox(height: KnSize.space16),
                            Container(
                              padding: const EdgeInsets.all(KnSize.space16),
                              decoration: BoxDecoration(
                                color: kn.bgSurface,
                                borderRadius: BorderRadius.circular(KnSize.radiusLg),
                                border: Border.all(color: kn.borderDefault),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(color: kn.actionSecondary, shape: BoxShape.circle),
                                    child: Icon(LucideIcons.fileText, size: 18, color: kn.textPrimary),
                                  ),
                                  const SizedBox(width: KnSize.space12),
                                  Expanded(
                                    child: CustomBaseTextWidget(
                                      LangKeys.billPaymentsNote.tr,
                                      style: text.caption,
                                      color: kn.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
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

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final mark = icon;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: KnPrimitive.cream100.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(KnSize.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mark != null) ...[Icon(mark, size: 14, color: KnPrimitive.cream50), const SizedBox(width: 6)],
          CustomBaseTextWidget(label, style: context.knText.labelSm, color: KnPrimitive.cream50),
        ],
      ),
    );
  }
}

class _UsageTile extends StatelessWidget {
  const _UsageTile({super.key, required this.view, required this.onTap});

  final UsageView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusMd);
    final f = view.fraction;
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: view.label,
      child: Ink(
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomBaseTextWidget(view.label, style: text.caption, color: kn.textSecondary, maxLines: 1),
            const SizedBox(height: 4),
            CustomBaseTextWidget(view.value, style: text.label, color: view.full ? kn.statusWarning : kn.textPrimary, maxLines: 1),
            const Spacer(),
            if (f != null) ...[
              const SizedBox(height: KnSize.space8),
              ClipRRect(
                borderRadius: BorderRadius.circular(KnSize.radiusFull),
                child: Stack(
                  children: [
                    Container(height: 5, color: kn.bgSurface.withValues(alpha: 0.7)),
                    FractionallySizedBox(
                      widthFactor: f,
                      child: Container(height: 5, color: view.full ? kn.statusWarning : kn.textPrimary),
                    ),
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
