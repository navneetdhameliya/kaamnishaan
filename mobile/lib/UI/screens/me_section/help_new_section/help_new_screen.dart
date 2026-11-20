import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_custom_text_form_field.dart';
import '../../../common_widgets/kn_inline_error.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_select_card.dart';
import '../../../common_widgets/kn_text_box.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'help_new_controller.dart';

/// M47 New help request.
class HelpNewScreen extends GetView<HelpNewController> {
  const HelpNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return KnPageScaffold(
      body: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: KnSize.space16),
            CustomBaseTextWidget(LangKeys.helpNewTitle.tr, style: text.h2),
            const SizedBox(height: KnSize.space4),
            CustomBaseTextWidget(LangKeys.helpNewBody.tr, style: text.body, color: kn.textSecondary),
            const SizedBox(height: KnSize.space24),
            CustomBaseTextWidget(LangKeys.helpAbout.tr, style: text.label),
            const SizedBox(height: KnSize.space8),
            for (final c in HelpNewController.categories) ...[
              KnSelectCard(
                key: ValueKey('help-cat-$c'),
                title: controller.label(c),
                subtitle: controller.hint(c),
                selected: controller.category.value == c,
                onTap: () => controller.category.value = c,
              ),
              const SizedBox(height: KnSize.space8),
            ],
            const SizedBox(height: KnSize.space16),
            KnCustomTextFormField(
              fieldKey: const ValueKey('help-subject'),
              label: LangKeys.helpSubject.tr,
              hintText: LangKeys.helpSubjectHint.tr,
              controller: controller.subject,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: KnSize.space16),
            CustomBaseTextWidget(LangKeys.helpMessage.tr, style: text.label),
            const SizedBox(height: KnSize.space8),
            KnTextBox(
              fieldKey: const ValueKey('help-message'),
              controller: controller.message,
              hint: LangKeys.helpMessageHint.tr,
              minLines: 5,
              maxLines: 10,
              maxLength: 4000,
            ),
            if (controller.error.value != null) ...[
              const SizedBox(height: KnSize.space12),
              KnInlineError(message: controller.error.value!),
            ],
            const SizedBox(height: KnSize.space24),
          ],
        ),
      ),
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('help-send'),
              text: LangKeys.helpSend.tr,
              icon: LucideIcons.send,
              loading: controller.sending.value,
              enabled: controller.ready,
              onTap: controller.onSend,
              onDisabledTap: controller.onDisabledTap,
            ),
          ),
        ],
      ),
    );
  }
}
