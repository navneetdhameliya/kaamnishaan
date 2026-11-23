import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_custom_text_form_field.dart';
import '../../../common_widgets/kn_dictation.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'quick_job_controller.dart';

/// Quick job: work that wasn't planned (no Figma frame: the sign-up form's fields, with the microphone).
class QuickJobScreen extends GetView<QuickJobController> {
  const QuickJobScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return KnPageScaffold(
      body: Obx(() {
        final c = controller;
        final errors = c.errors;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: KnSize.space16),
            CustomBaseTextWidget(LangKeys.qjTitle.tr, style: text.h2),
            const SizedBox(height: KnSize.space8),
            CustomBaseTextWidget(LangKeys.qjSub.tr, style: text.body, color: kn.textSecondary),
            const SizedBox(height: KnSize.space24),
            KnCustomTextFormField(
              fieldKey: const ValueKey('qj-work'),
              label: LangKeys.qjWork.tr,
              hintText: LangKeys.qjWorkHint.tr,
              controller: c.work,
              errorText: errors['work'],
              onChanged: (_) => c.clearError('work'),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              trailing: KnMicButton(
                key: const ValueKey('qj-work-mic'),
                dictation: c.dictation,
                box: c.work,
                size: 40,
                onText: (_) => c.clearError('work'),
              ),
            ),
            KnDictationNote(dictation: c.dictation, box: c.work),
            const SizedBox(height: KnSize.space16),
            KnCustomTextFormField(
              fieldKey: const ValueKey('qj-customer'),
              label: LangKeys.qjCustomer.tr,
              hintText: LangKeys.customersNameHint.tr,
              controller: c.customer,
              errorText: errors['customer'],
              onChanged: (_) => c.clearError('customer'),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              trailing: KnMicButton(
                key: const ValueKey('qj-customer-mic'),
                dictation: c.dictation,
                box: c.customer,
                size: 40,
                onText: (_) => c.clearError('customer'),
              ),
            ),
            KnDictationNote(dictation: c.dictation, box: c.customer),
            const SizedBox(height: KnSize.space16),
            KnCustomTextFormField(
              fieldKey: const ValueKey('qj-phone'),
              label: LangKeys.qjPhone.tr,
              hintText: LangKeys.customersPhoneHint.tr,
              controller: c.phone,
              errorText: errors['phone'],
              onChanged: (_) => c.clearError('phone'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: KnSize.space16),
            KnCustomTextFormField(
              fieldKey: const ValueKey('qj-address'),
              label: LangKeys.qjAddress.tr,
              hintText: LangKeys.customersLine1Hint.tr,
              controller: c.address,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: KnSize.space24),
          ],
        );
      }),
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('qj-start'),
              text: LangKeys.jobStart.tr,
              icon: LucideIcons.play,
              loading: controller.saving.value,
              onTap: controller.onStartTap,
            ),
          ),
        ],
      ),
    );
  }
}
