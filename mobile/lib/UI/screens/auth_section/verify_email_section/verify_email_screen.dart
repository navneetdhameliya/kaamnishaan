import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_step_header.dart';
import '../../../common_widgets/kn_text_box.dart';
import '../../../common_widgets/kn_text_link.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'verify_email_controller.dart';

/// M09 Verify email (Figma 247:2200).
class VerifyEmailScreen extends GetView<VerifyEmailController> {
  const VerifyEmailScreen({super.key});

  void _change() {
    controller.startChange();
    showKnBottomSheet<void>(
      title: LangKeys.veChangeTitle.tr,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(Get.context!).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomBaseTextWidget(LangKeys.veChangeLabel.tr, style: Get.context!.knText.label),
            const SizedBox(height: KnSize.space8),
            KnTextBox(
              fieldKey: const ValueKey('verify-new-email'),
              controller: controller.newEmail,
              hint: 'name@company.com',
              minLines: 1,
              maxLines: 1,
              maxLength: 254,
            ),
            const SizedBox(height: KnSize.space16),
            Obx(
              () => KnCustomButton(
                key: const ValueKey('verify-change-send'),
                text: LangKeys.veChangeSend.tr,
                loading: controller.changing.value,
                enabled: controller.newEmailDraft.value.trim().isNotEmpty,
                onTap: () async {
                  if (await controller.onChangeEmail()) Get.back<void>();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return KnPageScaffold(
      header: KnStepHeader(title: LangKeys.veTitle.tr, subtitle: LangKeys.veStep.tr, step: 1, steps: 2),
      footer: KnScreenFooter(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IntrinsicWidth(
              child: KnCustomButton(
                key: const ValueKey('verify-open-mail'),
                text: LangKeys.veOpenMail.tr,
                icon: LucideIcons.share,
                onTap: controller.onOpenMailTap,
              ),
            ),
          ),
          Obx(
            () => Align(
              alignment: Alignment.centerLeft,
              child: IntrinsicWidth(
                child: KnCustomButton(
                  key: const ValueKey('verify-resend'),
                  text: LangKeys.veResend.tr,
                  icon: LucideIcons.refreshCw,
                  variant: KnButtonVariant.secondary,
                  loading: controller.resending.value,
                  enabled: controller.secondsLeft.value == 0,
                  onDisabledTap: () {},
                  onTap: controller.onResendTap,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: KnSize.space24),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(color: kn.statusSuccessBg, shape: BoxShape.circle),
                child: Icon(LucideIcons.check, size: 44, color: kn.statusSuccess),
              ),
            ),
            const SizedBox(height: KnSize.space16),
            CustomBaseTextWidget(LangKeys.veHead.tr, style: text.h1, textAlign: TextAlign.center),
            const SizedBox(height: KnSize.space12),
            CustomBaseTextWidget(
              LangKeys.veBody.trParams({'email': controller.email}),
              style: text.bodyLg,
              color: kn.textSecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KnSize.space24),
            Container(
              padding: const EdgeInsets.all(KnSize.space16),
              decoration: BoxDecoration(
                color: kn.bgSurface,
                borderRadius: BorderRadius.circular(KnSize.radiusLg),
                border: Border.all(color: kn.borderDefault),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: kn.actionPrimary, shape: BoxShape.circle),
                        child: Icon(LucideIcons.check, size: 18, color: kn.textOnAction),
                      ),
                      const SizedBox(width: KnSize.space12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(LangKeys.veMailFrom.tr, style: text.label),
                          CustomBaseTextWidget(LangKeys.veMailWhen.tr, style: text.caption, color: kn.textSecondary),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space12),
                  CustomBaseTextWidget(LangKeys.veMailSubject.tr, style: text.label),
                  const SizedBox(height: 4),
                  CustomBaseTextWidget(LangKeys.veMailBody.tr, style: text.body, color: kn.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: KnSize.space16),
            if (controller.secondsLeft.value > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.clock, size: 16, color: kn.textSecondary),
                  const SizedBox(width: 6),
                  CustomBaseTextWidget(
                    LangKeys.veResendIn.trParams({'time': controller.waitText}),
                    style: text.labelSm,
                    color: kn.textSecondary,
                  ),
                ],
              ),
            const SizedBox(height: KnSize.space12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CustomBaseTextWidget(LangKeys.veWrong.tr, style: text.labelSm, color: kn.textSecondary),
                const SizedBox(width: 4),
                KnTextLink(key: const ValueKey('verify-change'), text: LangKeys.veChange.tr, onTap: _change),
              ],
            ),
            const SizedBox(height: KnSize.space8),
            Center(
              child: KnTextLink(key: const ValueKey('verify-later'), text: LangKeys.veLater.tr, onTap: controller.onLaterTap),
            ),
            const SizedBox(height: KnSize.space24),
          ],
        ),
      ),
    );
  }
}
