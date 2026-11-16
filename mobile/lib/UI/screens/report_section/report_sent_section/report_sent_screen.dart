import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_cover_image.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'report_sent_controller.dart';

/// M31 Report sent to manager (Figma 32:1472).
class ReportSentScreen extends GetView<ReportSentController> {
  const ReportSentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.onBackTodayTap();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: kn.bgCanvas,
          bottomNavigationBar: KnScreenFooter(
            children: [
              KnCustomButton(
                key: const ValueKey('sent-back-today'),
                text: LangKeys.sentBackToday.tr,
                icon: LucideIcons.house,
                onTap: controller.onBackTodayTap,
              ),
              KnCustomButton(
                key: const ValueKey('sent-see-report'),
                text: LangKeys.sentSeeReport.tr,
                variant: KnButtonVariant.ghost,
                onTap: controller.onSeeReportTap,
              ),
            ],
          ),
          body: Stack(
            children: [
              // the dark top with soft rings
              Container(
                height: 420,
                decoration: const BoxDecoration(
                  color: KnPrimitive.mocha900,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned(right: -60, top: -40, child: _ring(200)),
                    Positioned(left: -90, top: 270, child: _ring(160)),
                  ],
                ),
              ),
              SafeArea(
                bottom: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(KnSize.space16, 48, KnSize.space16, KnSize.space24),
                  children: [
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: kn.statusSuccess.withValues(alpha: 0.25),
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusSuccess),
                          child: const Icon(LucideIcons.check, size: 44, color: KnPrimitive.cream50),
                        ),
                      ),
                    ),
                    const SizedBox(height: KnSize.space24),
                    CustomBaseTextWidget(
                      LangKeys.sentTitle.tr,
                      style: text.h1,
                      color: KnPrimitive.cream50,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: KnSize.space8),
                    CustomBaseTextWidget(
                      LangKeys.sentBody.tr,
                      style: text.bodyLg,
                      color: KnPrimitive.cream400,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: KnSize.space24),
                    Obx(
                      () => Container(
                        padding: const EdgeInsets.all(KnSize.space16),
                        decoration: BoxDecoration(
                          color: kn.bgSurface,
                          borderRadius: BorderRadius.circular(KnSize.radiusLg),
                          border: Border.all(color: kn.borderDefault),
                          boxShadow: KnShadow.lg,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(KnSize.radiusMd),
                                  child: KnCoverImage(url: controller.cover, width: 64, height: 64),
                                ),
                                const SizedBox(width: KnSize.space12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CustomBaseTextWidget(controller.args.customer, style: text.label, maxLines: 1),
                                      const SizedBox(height: 2),
                                      CustomBaseTextWidget(controller.meta, style: text.caption, color: kn.textSecondary),
                                      CustomBaseTextWidget(controller.sentAt, style: text.caption, color: kn.textSecondary),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: KnSize.space12),
                            Divider(height: 1, color: kn.borderDefault),
                            const SizedBox(height: KnSize.space12),
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
                                  child: Icon(LucideIcons.userCheck, size: 20, color: kn.textPrimary),
                                ),
                                const SizedBox(width: KnSize.space12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CustomBaseTextWidget(LangKeys.sentReviewer.tr, style: text.label),
                                      CustomBaseTextWidget(
                                        LangKeys.sentReviewerMeta.tr,
                                        style: text.caption,
                                        color: kn.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: KnSize.space8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: kn.statusWarningBg,
                                    borderRadius: BorderRadius.circular(KnSize.radiusFull),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.clock, size: 14, color: kn.statusWarning),
                                      const SizedBox(width: 4),
                                      CustomBaseTextWidget(LangKeys.sentReview.tr, style: text.labelSm, color: kn.statusWarning),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ring(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: KnPrimitive.cream100.withValues(alpha: 0.12), width: 28),
        ),
      );
}
