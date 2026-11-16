import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_country_picker_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_inline_error.dart';
import '../../../common_widgets/kn_number_keypad.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_phone_field.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'phone_controller.dart';

/// M05 Phone number (Figma 16:768; invalid 71:2030; choose country 71:2129).
class PhoneScreen extends GetView<PhoneController> {
  const PhoneScreen({super.key});

  void _openCountries() {
    showKnBottomSheet<void>(
      title: LangKeys.authChooseCountry.tr,
      child: KnCountryPickerSheet(
        countries: controller.config.countries,
        selected: controller.country.value,
        onSelected: controller.onCountrySelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return KnPageScaffold(
      scroll: false,
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('send-code'),
              text: LangKeys.authSendCode.tr,
              icon: LucideIcons.chevronRight,
              enabled: controller.isValid,
              loading: controller.apiCallLoader.value,
              onTap: controller.callSendOtpAPI,
              onDisabledTap: controller.onDisabledSendTap,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(LangKeys.authPhoneTitle.tr, style: text.h1),
          const SizedBox(height: KnSize.space4),
          CustomBaseTextWidget(LangKeys.authCodeSent.tr, style: text.bodyLg, color: kn.textSecondary),
          const SizedBox(height: KnSize.space24),
          CustomBaseTextWidget(LangKeys.authPhoneLabel.tr, style: text.label),
          const SizedBox(height: KnSize.space8),
          Obx(
            () => KnPhoneField(
              flag: controller.country.value.flag,
              dialCode: controller.country.value.dialCode,
              number: controller.formatted,
              hasError: controller.showError.value,
              onCountryTap: _openCountries,
            ),
          ),
          const SizedBox(height: KnSize.space8),
          Obx(
            () => controller.showError.value
                ? KnInlineError(message: controller.errorText, onHear: controller.onHearErrorTap)
                : Row(
                    children: [
                      Icon(LucideIcons.lock, size: 14, color: kn.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: CustomBaseTextWidget(
                          LangKeys.authPhonePrivacy.tr,
                          style: text.caption,
                          color: kn.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
          const Spacer(),
          KnNumberKeypad(onDigit: controller.onDigit, onBackspace: controller.onBackspace),
          const SizedBox(height: KnSize.space12),
        ],
      ),
    );
  }
}
