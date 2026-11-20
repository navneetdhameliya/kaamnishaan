import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'company_paused_controller.dart';

/// Company paused by KaamNishaan (not designed yet; uses the approved buttons and type styles).
class CompanyPausedScreen extends GetView<CompanyPausedController> {
  const CompanyPausedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    final kn = context.kn;
    return KnPageScaffold(
      showBack: false,
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              text: LangKeys.commonRetry.tr,
              icon: LucideIcons.refreshCw,
              loading: controller.apiCallLoader.value,
              onTap: controller.callRefreshAPI,
            ),
          ),
          if (controller.canSwitch) ...[
            const SizedBox(height: KnSize.space12),
            KnCustomButton(
              text: LangKeys.companyPausedSwitch.tr,
              icon: LucideIcons.repeat,
              variant: KnButtonVariant.secondary,
              onTap: controller.onSwitchTap,
            ),
          ],
          const SizedBox(height: KnSize.space12),
          KnCustomButton(
            text: LangKeys.commonLogOut.tr,
            icon: LucideIcons.logOut,
            variant: KnButtonVariant.ghost,
            onTap: controller.onLogoutTap,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KnSize.space48),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: kn.statusWarningBg, shape: BoxShape.circle),
            child: Icon(LucideIcons.circlePause, size: 30, color: kn.statusWarning),
          ),
          const SizedBox(height: KnSize.space24),
          CustomBaseTextWidget(LangKeys.companyPausedTitle.tr, style: text.h1),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(
            LangKeys.companyPausedBody.trParams({'company': controller.companyName}),
            style: text.bodyLg,
            color: kn.textSecondary,
          ),
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(LangKeys.companyPausedOwner.tr, style: text.body, color: kn.textSecondary),
        ],
      ),
    );
  }
}
