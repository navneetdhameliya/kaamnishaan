import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_custom_text_form_field.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'forgot_password_controller.dart';

/// M08 Forgot password (Figma 40:745).
class ForgotPasswordScreen extends GetView<ForgotPasswordController> {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return KnPageScaffold(
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('send-link'),
              text: LangKeys.forgotSend.tr,
              enabled: controller.canSubmit,
              loading: controller.apiCallLoader.value,
              onTap: controller.callSendLinkAPI,
              onDisabledTap: controller.onDisabledSendTap,
            ),
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
          const SizedBox(height: KnSize.space24),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
              child: Icon(LucideIcons.lock, size: 32, color: kn.textLink),
            ),
          ),
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(LangKeys.forgotTitle.tr, style: text.h1),
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(LangKeys.forgotBody.tr, style: text.bodyLg, color: kn.textSecondary),
          const SizedBox(height: 28),
          Obx(
            () => KnCustomTextFormField(
              fieldKey: const ValueKey('forgot-email'),
              label: LangKeys.loginEmailLabel.tr,
              controller: controller.emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              autofillHints: const [AutofillHints.email],
              onChanged: controller.onEmailChanged,
              onSubmitted: (_) => controller.callSendLinkAPI(),
              errorText: controller.showEmailError.value ? LangKeys.loginEmailInvalid.tr : null,
              onHearError: controller.onHearErrorTap,
            ),
          ),
          const SizedBox(height: KnSize.space12),
          Container(
            padding: const EdgeInsets.all(KnSize.space12),
            decoration: BoxDecoration(
              color: kn.bgSubtle,
              borderRadius: BorderRadius.circular(KnSize.radiusLg),
              border: Border.all(color: kn.borderDefault),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.shield, size: 20, color: kn.textSecondary),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  child: CustomBaseTextWidget(LangKeys.forgotTip.tr, style: text.caption, color: kn.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: KnSize.space24),
        ],
      ),
    );
  }
}
