import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_custom_text_form_field.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_text_box.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'customer_edit_controller.dart';

/// Add customer / Edit customer (no Figma frame: the sign-up form's fields, grouped as Who, Reach them,
/// Address and Note).
class CustomerEditScreen extends GetView<CustomerEditController> {
  const CustomerEditScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    Widget section(String title) => Padding(
          padding: const EdgeInsets.only(top: KnSize.space24, bottom: KnSize.space8),
          child: CustomBaseTextWidget(title, style: text.label, color: kn.textSecondary),
        );
    return KnPageScaffold(
      body: Obx(() {
        final errors = controller.errors;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: KnSize.space16),
            CustomBaseTextWidget(controller.title, style: text.h2),
            const SizedBox(height: KnSize.space16),
            KnCustomTextFormField(
              fieldKey: const ValueKey('customer-name'),
              label: LangKeys.customersName.tr,
              hintText: LangKeys.customersNameHint.tr,
              controller: controller.name,
              errorText: errors['name'],
              onChanged: (_) => controller.clearError('name'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            section(LangKeys.customersReach.tr),
            KnCustomTextFormField(
              fieldKey: const ValueKey('customer-phone'),
              label: LangKeys.customersPhone.tr,
              hintText: LangKeys.customersPhoneHint.tr,
              controller: controller.phone,
              errorText: errors['phone'],
              onChanged: (_) => controller.clearError('phone'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: KnSize.space12),
            KnCustomTextFormField(
              fieldKey: const ValueKey('customer-email'),
              label: LangKeys.customersEmail.tr,
              hintText: LangKeys.customersEmailHint.tr,
              controller: controller.email,
              errorText: errors['email'],
              onChanged: (_) => controller.clearError('email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            section(LangKeys.customersAddress.tr),
            KnCustomTextFormField(
              fieldKey: const ValueKey('customer-line1'),
              label: LangKeys.customersLine1.tr,
              hintText: LangKeys.customersLine1Hint.tr,
              controller: controller.line1,
              errorText: errors['address'],
              onChanged: (_) => controller.clearError('address'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: KnSize.space12),
            KnCustomTextFormField(
              fieldKey: const ValueKey('customer-line2'),
              label: LangKeys.customersLine2.tr,
              controller: controller.line2,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: KnSize.space12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: KnCustomTextFormField(
                    fieldKey: const ValueKey('customer-city'),
                    label: LangKeys.customersCity.tr,
                    controller: controller.city,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  flex: 2,
                  child: KnCustomTextFormField(
                    fieldKey: const ValueKey('customer-postcode'),
                    label: LangKeys.customersPostcode.tr,
                    controller: controller.postcode,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            section(LangKeys.customersNote.tr),
            KnTextBox(
              fieldKey: const ValueKey('customer-notes'),
              controller: controller.notes,
              hint: LangKeys.customersNoteHint.tr,
              minLines: 3,
              maxLines: 6,
              maxLength: 2000,
            ),
            const SizedBox(height: KnSize.space24),
          ],
        );
      }),
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('customer-save'),
              text: controller.isNew ? LangKeys.customersAdd.tr : LangKeys.customersSave.tr,
              icon: LucideIcons.check,
              loading: controller.saving.value,
              onTap: controller.onSave,
            ),
          ),
        ],
      ),
    );
  }
}
