import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_text_link.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'check_email_controller.dart';
import 'custom_widgets/mail_preview_card.dart';

/// M08 Check your email (Figma 40:789).
class CheckEmailScreen extends GetView<CheckEmailController> {
  const CheckEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return KnPageScaffold(
      backIcon: LucideIcons.x,
      onBack: controller.onBackToLoginTap,
      footer: KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('open-mail'),
            text: LangKeys.forgotOpenMail.tr,
            onTap: controller.onOpenMailTap,
          ),
          KnCustomButton(
            key: const ValueKey('back-to-login'),
            text: LangKeys.forgotBackToLogin.tr,
            variant: KnButtonVariant.ghost,
            onTap: controller.onBackToLoginTap,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 52),
          Center(
            child: Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: kn.statusSuccessBg.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: kn.statusSuccessBg, shape: BoxShape.circle),
                child: Icon(LucideIcons.mail, size: 44, color: kn.statusSuccess),
              ),
            ),
          ),
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(LangKeys.forgotCheckTitle.tr, style: text.h1, textAlign: TextAlign.center),
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(
            LangKeys.forgotCheckBody.trParams({'email': controller.email}),
            style: text.bodyLg,
            color: kn.textSecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          const MailPreviewCard(),
          const SizedBox(height: KnSize.space12),
          Obx(() => _hint(context)),
          const SizedBox(height: KnSize.space24),
        ],
      ),
    );
  }

  Widget _hint(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final waiting = controller.secondsLeft.value > 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.clock, size: 16, color: kn.textSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: CustomBaseTextWidget(
            waiting ? LangKeys.forgotResendIn.trParams({'time': controller.waitText}) : LangKeys.forgotResendNow.tr,
            style: text.caption,
            color: kn.textSecondary,
          ),
        ),
        if (!waiting) ...[
          const SizedBox(width: KnSize.space4),
          KnTextLink(
            key: const ValueKey('send-again'),
            text: LangKeys.authSendAgain.tr,
            onTap: controller.callResendAPI,
          ),
        ],
      ],
    );
  }
}
