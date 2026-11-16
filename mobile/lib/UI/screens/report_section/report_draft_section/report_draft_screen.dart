import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/report_card.dart';
import 'report_draft_controller.dart';

/// M31 Report draft (Figma 31:1401); after sending, the same report read-only.
class ReportDraftScreen extends GetView<ReportDraftController> {
  const ReportDraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: Obx(
        () => controller.canEdit
            ? KnScreenFooter(
                children: [
                  Row(
                    children: [
                      KnCustomButton(
                        key: const ValueKey('report-edit'),
                        text: LangKeys.reportEdit.tr,
                        icon: LucideIcons.pencil,
                        variant: KnButtonVariant.secondary,
                        onTap: controller.onEditTap,
                      ),
                      const SizedBox(width: KnSize.space12),
                      Expanded(
                        child: KnCustomButton(
                          key: const ValueKey('report-send'),
                          text: LangKeys.reportSendManager.tr,
                          icon: LucideIcons.send,
                          enabled: controller.canSend,
                          loading: controller.sending.value,
                          onTap: controller.onSendTap,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: Obx(() {
              final r = controller.report.value;
              return ListView(
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
                            CustomBaseTextWidget(controller.title, style: text.h3),
                            CustomBaseTextWidget(controller.subtitle, style: text.caption, color: kn.textSecondary, maxLines: 1),
                          ],
                        ),
                      ),
                      if (r != null)
                        CustomInkWell(
                          key: const ValueKey('report-speak'),
                          onTap: controller.onSpeakTap,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: kn.bgSurface,
                              border: Border.all(color: kn.borderDefault),
                            ),
                            child: Icon(LucideIcons.volume2, size: 20, color: kn.textPrimary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space16),
                  if (r == null) ...const [
                    CommonShimmer(height: 56, radius: KnSize.radiusLg),
                    SizedBox(height: KnSize.space12),
                    CommonShimmer(height: 420, radius: KnSize.radiusLg),
                  ] else ...[
                    if (controller.stateText != null) ...[
                      StateBanner(text: controller.stateText!, status: r.status, note: controller.changeNote),
                      const SizedBox(height: KnSize.space12),
                    ],
                    if (controller.canEdit) ...[
                      Container(
                        padding: const EdgeInsets.all(KnSize.space12),
                        decoration: BoxDecoration(
                          color: kn.actionSecondary,
                          borderRadius: BorderRadius.circular(KnSize.radiusLg),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: kn.bgSurface),
                              child: Icon(LucideIcons.sparkle, size: 14, color: kn.textPrimary),
                            ),
                            const SizedBox(width: KnSize.space12),
                            Expanded(child: CustomBaseTextWidget(controller.proofText, style: text.caption)),
                          ],
                        ),
                      ),
                      const SizedBox(height: KnSize.space12),
                    ],
                    for (final f in controller.missing) ...[
                      MissingBanner(text: f.text, onTakePhoto: () => controller.onTakePhotoTap(f)),
                      const SizedBox(height: KnSize.space12),
                    ],
                    ReportCard(controller: controller),
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
