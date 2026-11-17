import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/pdf_page.dart';
import 'report_pdf_controller.dart';

/// M34 Report PDF (Figma 47:1398; building 48:1364).
class ReportPdfScreen extends GetView<ReportPdfController> {
  const ReportPdfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Obx(
      () => Scaffold(
        backgroundColor: kn.actionSecondary,
        bottomNavigationBar: KnScreenFooter(
          children: [
            Row(
              children: [
                Expanded(
                  child: KnCustomButton(
                    key: const ValueKey('pdf-download'),
                    text: LangKeys.pdfDownload.tr,
                    variant: KnButtonVariant.secondary,
                    enabled: controller.ready,
                    onTap: controller.onDownloadTap,
                  ),
                ),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  child: KnCustomButton(
                    key: const ValueKey('pdf-share'),
                    text: LangKeys.pdfShare.tr,
                    icon: LucideIcons.share,
                    enabled: controller.ready,
                    onTap: controller.onShareTap,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: ListView(
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
                          CustomBaseTextWidget(LangKeys.pdfTitle.tr, style: text.h3),
                          CustomBaseTextWidget(
                            controller.ready
                                ? LangKeys.pdfSubtitle.trParams({'number': controller.number, 'n': '${controller.pages}'})
                                : '#${controller.number}',
                            style: text.caption,
                            color: kn.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KnSize.space16),
                Stack(
                  children: [
                    Opacity(opacity: controller.ready ? 1 : 0.35, child: PdfPage(controller: controller)),
                    if (!controller.ready)
                      Positioned.fill(
                        child: Align(
                          alignment: const Alignment(0, -0.5),
                          child: controller.failed ? _failed(context) : _building(context),
                        ),
                      ),
                  ],
                ),
                if (controller.ready) ...[
                  const SizedBox(height: KnSize.space16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: 6),
                      decoration: BoxDecoration(
                        color: kn.actionPrimary,
                        borderRadius: BorderRadius.circular(KnSize.radiusFull),
                      ),
                      child: CustomBaseTextWidget(
                        LangKeys.pdfPage.trParams({'n': '${controller.pages}'}),
                        style: text.labelSm,
                        color: kn.textOnAction,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box(BuildContext context, List<Widget> children) {
    final kn = context.kn;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: KnSize.space16),
      padding: const EdgeInsets.all(KnSize.space24),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
        boxShadow: KnShadow.lg,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _building(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return _box(context, [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
        child: Icon(LucideIcons.sparkle, size: 24, color: kn.textPrimary),
      ),
      const SizedBox(height: KnSize.space12),
      CustomBaseTextWidget(LangKeys.pdfBuilding.tr, style: text.h3, textAlign: TextAlign.center),
      const SizedBox(height: KnSize.space4),
      CustomBaseTextWidget(LangKeys.pdfBuildingBody.tr, style: text.caption, color: kn.textSecondary, textAlign: TextAlign.center),
      const SizedBox(height: KnSize.space12),
      ClipRRect(
        borderRadius: BorderRadius.circular(KnSize.radiusFull),
        child: LinearProgressIndicator(minHeight: 6, color: kn.actionPrimary, backgroundColor: kn.actionSecondary),
      ),
    ]);
  }

  Widget _failed(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return _box(context, [
      Icon(LucideIcons.circleAlert, size: 32, color: kn.statusDanger),
      const SizedBox(height: KnSize.space12),
      CustomBaseTextWidget(LangKeys.pdfFailed.tr, style: text.h3, textAlign: TextAlign.center),
      const SizedBox(height: KnSize.space12),
      KnCustomButton(
        key: const ValueKey('pdf-retry'),
        text: LangKeys.pdfTryAgain.tr,
        icon: LucideIcons.rotateCw,
        small: true,
        onTap: controller.onTryAgainTap,
      ),
    ]);
  }
}
