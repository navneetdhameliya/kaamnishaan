import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_hint_box.dart';
import '../../../common_widgets/kn_inline_error.dart';
import '../../../common_widgets/kn_number_keypad.dart';
import '../../../common_widgets/kn_otp_boxes.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'otp_controller.dart';

/// M05 SMS code (Figma 16:834; wrong code 72:2244; code expired 72:2311).
class OtpScreen extends GetView<OtpController> {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Obx(() {
      final state = controller.state.value;
      final expired = state == KnOtpState.expired;
      return KnPageScaffold(
        scroll: false,
        footer: expired
            ? KnScreenFooter(
                children: [
                  KnCustomButton(
                    key: const ValueKey('send-new-code'),
                    text: LangKeys.authSendNewCode.tr,
                    icon: LucideIcons.rotateCw,
                    loading: controller.apiCallLoader.value,
                    onTap: controller.callResendOtpAPI,
                  ),
                  KnCustomButton(
                    text: LangKeys.authChangeNumber.tr,
                    variant: KnButtonVariant.ghost,
                    onTap: controller.onChangeNumberTap,
                  ),
                ],
              )
            : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: KnSize.space12),
            CustomBaseTextWidget(LangKeys.authCodeTitle.tr, style: text.h1),
            const SizedBox(height: KnSize.space4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: KnSize.space8,
              children: [
                CustomBaseTextWidget(
                  LangKeys.authSentTo.trParams({'phone': controller.args.display}),
                  style: text.body,
                  color: kn.textSecondary,
                ),
                CustomInkWell(
                  onTap: controller.onChangeNumberTap,
                  borderRadius: BorderRadius.circular(KnSize.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: KnSize.space4),
                    child: CustomBaseTextWidget(LangKeys.authChange.tr, style: text.label, color: kn.textLink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: KnSize.space24),
            KnOtpBoxes(code: controller.code.value, state: state),
            const SizedBox(height: KnSize.space16),
            if (state != KnOtpState.normal) ...[
              KnInlineError(message: controller.errorMessage.value, onHear: controller.onHearErrorTap),
              const SizedBox(height: KnSize.space12),
            ],
            if (expired)
              KnHintBox(
                icon: LucideIcons.clock,
                text: LangKeys.authCodeValidFor.trParams({'time': controller.sentAtText}),
              )
            else ...[
              // after a wrong code Figma offers "Send again" straight away
              if (controller.secondsLeft.value > 0 && state == KnOtpState.normal)
                Row(
                  children: [
                    Icon(LucideIcons.clock, size: 18, color: kn.textSecondary),
                    const SizedBox(width: 6),
                    CustomBaseTextWidget(controller.resendText, style: text.body, color: kn.textSecondary),
                  ],
                )
              else
                CustomInkWell(
                  key: const ValueKey('send-again'),
                  onTap: controller.callResendOtpAPI,
                  borderRadius: BorderRadius.circular(KnSize.radiusSm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: KnSize.space4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.rotateCw, size: 18, color: kn.textSecondary),
                        const SizedBox(width: 6),
                        CustomBaseTextWidget(LangKeys.authSendAgain.tr, style: text.label, color: kn.textSecondary),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: KnSize.space16),
              KnHintBox(icon: LucideIcons.sparkles, text: LangKeys.authAutofillHint.tr),
            ],
            const Spacer(),
            if (!expired) ...[
              KnNumberKeypad(onDigit: controller.onDigit, onBackspace: controller.onBackspace),
              const SizedBox(height: KnSize.space32),
            ],
          ],
        ),
      );
    });
  }
}
