import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_glass_tab_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../../home_section/home_shell_section/home_shell_controller.dart';
import 'capture_hub_controller.dart';
import 'custom_widgets/proof_ring.dart';
import 'custom_widgets/proof_step_card.dart';

/// M19 Capture hub (Figma 21:1035; job not started 21:1150).
class CaptureHubScreen extends GetView<CaptureHubController> {
  const CaptureHubScreen({super.key});

  /// Design header is 216 tall with a 32 px status bar; steps start 20 px above its end.
  static const _headerHeight = 184.0;

  void _openTab(int i) {
    Get.until((route) => route.isFirst);
    if (Get.isRegistered<HomeShellController>()) Get.find<HomeShellController>().onTabTap(i);
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kn.bgCanvas,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => _footer(context)),
            ColoredBox(
              color: kn.bgCanvas,
              child: KnGlassTabBar(
                items: [
                  KnTabItem(icon: LucideIcons.house, label: LangKeys.navToday.tr),
                  KnTabItem(icon: LucideIcons.user, label: LangKeys.navMe.tr),
                ],
                index: -1,
                onTap: _openTab,
                onCapture: controller.onCaptureTap,
                captureLabel: LangKeys.navCapture.tr,
                captureActive: true,
              ),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: controller.load,
          edgeOffset: top,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Obx(
                () => Stack(
                  children: [
                    _header(context, top),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        KnSize.space16,
                        top + (controller.notStarted ? 136 : 164),
                        KnSize.space16,
                        KnSize.space16,
                      ),
                      child: _steps(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundButton({required Key key, required IconData icon, required String label, required VoidCallback onTap}) =>
      CustomInkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        semanticLabel: label,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: KnPrimitive.cream100.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 22, color: KnPrimitive.cream50),
        ),
      );

  Widget _header(BuildContext context, double top) {
    final text = context.knText;
    return Container(
      height: top + _headerHeight,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: KnPrimitive.mocha900,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 240,
            top: top + 58,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: KnPrimitive.mocha700.withValues(alpha: 0.6), width: 26),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(KnSize.space16, top + 8, KnSize.space16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _roundButton(
                      key: const ValueKey('hub-back'),
                      icon: LucideIcons.chevronLeft,
                      label: LangKeys.commonBack.tr,
                      onTap: Get.back,
                    ),
                    const SizedBox(width: KnSize.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(controller.customer, style: text.h3, color: KnPrimitive.cream50, maxLines: 1),
                          CustomBaseTextWidget(controller.subtitle, style: text.caption, color: KnPrimitive.cream400, maxLines: 1),
                        ],
                      ),
                    ),
                    const SizedBox(width: KnSize.space12),
                    _roundButton(
                      key: const ValueKey('hub-speak'),
                      icon: LucideIcons.volume2,
                      label: LangKeys.jobReadAloud.tr,
                      onTap: controller.onSpeakTap,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (controller.proof.value != null)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProofRing(done: controller.doneCount, total: controller.totalCount),
                      const SizedBox(width: KnSize.space16),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: KnSize.space8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CustomBaseTextWidget(controller.headline, style: text.h2, color: KnPrimitive.cream50),
                              const SizedBox(height: KnSize.space4),
                              CustomBaseTextWidget(controller.subline, style: text.body, color: KnPrimitive.cream400),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _steps(BuildContext context) {
    final kn = context.kn;
    final steps = controller.steps;
    if (controller.proof.value == null) {
      return Column(
        key: const ValueKey('hub-loading'),
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) const SizedBox(height: KnSize.space8),
            const CommonShimmer(height: 74, radius: KnSize.radiusLg),
          ],
        ],
      );
    }
    final locked = controller.notStarted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (locked) ...[
          Container(
            key: const ValueKey('start-first'),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
            decoration: BoxDecoration(
              color: kn.bgSubtle,
              borderRadius: BorderRadius.circular(KnSize.radiusMd),
              boxShadow: KnShadow.sm,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.sparkles, size: 16, color: kn.textPrimary),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  child: CustomBaseTextWidget(LangKeys.hubStartFirst.tr, style: context.knText.labelSm, maxLines: 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: KnSize.space8),
        ],
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: KnSize.space8),
          ProofStepCard(
            step: steps[i],
            next: controller.nextKey == steps[i].key,
            locked: locked,
            onTap: () => controller.onStepTap(steps[i]),
          ),
        ],
      ],
    );
  }

  Widget _footer(BuildContext context) {
    final kn = context.kn;
    final proof = controller.proof.value;
    if (proof == null) return const SizedBox.shrink();
    final hint = controller.unlockHint;
    return Container(
      padding: const EdgeInsets.fromLTRB(KnSize.space16, KnSize.space16, KnSize.space16, 0),
      decoration: BoxDecoration(color: kn.bgSurface, border: Border(top: BorderSide(color: kn.borderDefault))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (controller.notStarted)
            KnCustomButton(
              key: const ValueKey('hub-start'),
              text: LangKeys.jobStart.tr,
              icon: LucideIcons.play,
              loading: controller.starting.value,
              onTap: controller.onStartTap,
            )
          else
            KnCustomButton(
              key: const ValueKey('make-report'),
              text: LangKeys.hubMakeReport.tr,
              icon: LucideIcons.sparkles,
              enabled: proof.canMakeReport,
              onTap: controller.onMakeReportTap,
            ),
          if (!controller.notStarted && hint != null) ...[
            const SizedBox(height: KnSize.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.lock, size: 14, color: kn.textSecondary),
                const SizedBox(width: KnSize.space4),
                Flexible(
                  child: CustomBaseTextWidget(hint, style: context.knText.caption, color: kn.textSecondary),
                ),
              ],
            ),
          ],
          const SizedBox(height: KnSize.space16),
        ],
      ),
    );
  }
}
