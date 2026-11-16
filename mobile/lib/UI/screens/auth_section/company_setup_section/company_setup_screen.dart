import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_country_picker_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_custom_text_form_field.dart';
import '../../../common_widgets/kn_dropdown_field.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_select_card.dart';
import '../../../common_widgets/kn_step_header.dart';
import '../../../theme/kn_tokens.g.dart';
import 'company_setup_controller.dart';
import 'custom_widgets/company_preview_card.dart';
import 'custom_widgets/logo_upload_card.dart';

/// M07 Company setup, step 2 (Figma 39:793; missing details 76:2090).
class CompanySetupScreen extends GetView<CompanySetupController> {
  const CompanySetupScreen({super.key});

  void _openTrades() {
    showKnBottomSheet<void>(
      title: LangKeys.companyTradeLabel.tr,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final t in controller.config.trades) ...[
            Obx(
              () => KnSelectCard(
                key: ValueKey('trade-${t.key}'),
                title: t.name,
                selected: controller.trade.value?.key == t.key,
                onTap: () => controller.onTradeSelected(t),
              ),
            ),
            const SizedBox(height: KnSize.space8),
          ],
        ],
      ),
    );
  }

  void _openCountries() {
    showKnBottomSheet<void>(
      title: LangKeys.companyCountryLabel.tr,
      child: KnCountryPickerSheet(
        countries: controller.config.countries,
        selected: controller.country.value,
        onSelected: controller.onCountrySelected,
        showDialCode: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KnPageScaffold(
      header: KnStepHeader(
        title: LangKeys.companySetupTitle.tr,
        subtitle: LangKeys.companyStep.tr,
        step: 2,
        steps: 2,
      ),
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('create-company'),
              text: LangKeys.companyCreate.tr,
              enabled: controller.canSubmit,
              loading: controller.apiCallLoader.value,
              onTap: controller.callCreateCompanyAPI,
              onDisabledTap: controller.onDisabledCreateTap,
            ),
          ),
        ],
      ),
      body: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LogoUploadCard(key: const ValueKey('logo-upload'), logo: controller.logo.value?.bytes, onTap: controller.onLogoTap),
            const SizedBox(height: KnSize.space12),
            KnCustomTextFormField(
              fieldKey: const ValueKey('company-name'),
              label: LangKeys.companyNameLabel.tr,
              controller: controller.nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: controller.onNameChanged,
              errorText: controller.showNameError.value ? LangKeys.companyNameMissing.tr : null,
              onHearError: controller.onHearNameErrorTap,
            ),
            const SizedBox(height: KnSize.space12),
            KnDropdownField(
              key: const ValueKey('company-trade'),
              label: LangKeys.companyTradeLabel.tr,
              value: controller.trade.value?.name ?? '',
              placeholder: LangKeys.companyTradePlaceholder.tr,
              errorText: controller.showTradeError.value ? LangKeys.companyTradeMissing.tr : null,
              onHearError: controller.onHearTradeErrorTap,
              onTap: controller.config.trades.isEmpty ? null : _openTrades,
            ),
            const SizedBox(height: KnSize.space12),
            KnDropdownField(
              key: const ValueKey('company-country'),
              label: LangKeys.companyCountryLabel.tr,
              value: controller.country.value.name,
              onTap: controller.config.countries.isEmpty ? null : _openCountries,
            ),
            const SizedBox(height: KnSize.space12),
            CompanyPreviewCard(
              name: controller.name.value.trim().isEmpty
                  ? LangKeys.companyNamePlaceholder.tr
                  : controller.name.value.trim(),
              meta: controller.previewMeta,
              isPlaceholder: controller.name.value.trim().isEmpty,
            ),
            const SizedBox(height: KnSize.space24),
          ],
        ),
      ),
    );
  }
}
