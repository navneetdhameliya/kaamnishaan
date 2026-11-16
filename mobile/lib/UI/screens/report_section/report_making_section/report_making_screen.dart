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
import 'custom_widgets/making_widgets.dart';
import 'report_making_controller.dart';

/// M31 "Making your report" (Figma 30:1523) and "Could not make the report" (32:1520).
class ReportMakingScreen extends GetView<ReportMakingController> {
  const ReportMakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Obx(() {
      final failed = controller.phase.value == MakePhase.failed;
      return Scaffold(
        backgroundColor: kn.bgCanvas,
        bottomNavigationBar: failed
            ? KnScreenFooter(
                children: [
                  KnCustomButton(
                    key: const ValueKey('report-try-again'),
                    text: LangKeys.reportTryAgain.tr,
                    icon: LucideIcons.rotateCw,
                    onTap: controller.start,
                  ),
                  KnCustomButton(
                    key: const ValueKey('report-back-to-job'),
                    text: LangKeys.reportBackToJob.tr,
                    variant: KnButtonVariant.ghost,
                    onTap: controller.onBackTap,
                  ),
                ],
              )
            : null,
        body: SafeArea(
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                Row(
                  children: [
                    KnBackButton(onTap: controller.onBackTap),
                    const SizedBox(width: KnSize.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(LangKeys.reportYourReport.tr, style: text.h3),
                          CustomBaseTextWidget(
                            controller.args.customer,
                            style: text.caption,
                            color: kn.textSecondary,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KnSize.space24),
                if (failed) FailedView(args: controller.args) else MakingView(controller: controller),
              ],
            ),
          ),
        ),
      );
    });
  }
}
