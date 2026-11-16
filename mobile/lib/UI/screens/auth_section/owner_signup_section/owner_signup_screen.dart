import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_checkbox_tile.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_custom_text_form_field.dart';
import '../../../common_widgets/kn_initials_avatar.dart';
import '../../../common_widgets/kn_inline_error.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_step_header.dart';
import '../../../common_widgets/kn_text_link.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/password_strength.dart';
import 'owner_signup_controller.dart';

/// M07 Owner sign-up, step 1 (Figma 39:729; email used and weak password 76:1986).
class OwnerSignupScreen extends GetView<OwnerSignupController> {
  const OwnerSignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return KnPageScaffold(
      header: KnStepHeader(
        title: LangKeys.signupTitle.tr,
        subtitle: LangKeys.signupStep.tr,
        step: 1,
        steps: 2,
      ),
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('signup-next'),
              text: LangKeys.commonNext.tr,
              enabled: controller.canSubmit,
              loading: controller.apiCallLoader.value,
              onTap: controller.callRegisterAPI,
              onDisabledTap: controller.onDisabledNextTap,
            ),
          ),
        ],
      ),
      body: AutofillGroup(
        child: Obx(
          () => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!controller.emailTaken.value) ...[
                _ownerCard(context),
                const SizedBox(height: KnSize.space12),
              ],
              KnCustomTextFormField(
                fieldKey: const ValueKey('signup-name'),
                label: LangKeys.signupNameLabel.tr,
                controller: controller.nameController,
                focusNode: controller.nameFocusNode,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                onChanged: controller.onNameChanged,
                errorText: controller.nameError,
                onHearError: controller.onHearNameErrorTap,
                trailing: CustomInkWell(
                  onTap: controller.onMicTap,
                  borderRadius: BorderRadius.circular(20),
                  semanticLabel: LangKeys.signupNameLabel.tr,
                  child: Ink(
                    width: 32,
                    height: 40,
                    decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(20)),
                    child: Icon(LucideIcons.mic, size: 20, color: kn.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: KnSize.space12),
              Focus(
                onFocusChange: (focused) {
                  if (!focused) controller.onEmailDone();
                },
                child: KnCustomTextFormField(
                  fieldKey: const ValueKey('signup-email'),
                  label: LangKeys.loginEmailLabel.tr,
                  controller: controller.emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  onChanged: controller.onEmailChanged,
                  onSubmitted: controller.onEmailDone,
                  errorText: controller.emailError,
                  onHearError: controller.onHearEmailErrorTap,
                ),
              ),
              if (controller.emailTaken.value) ...[
                const SizedBox(height: KnSize.space12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: KnTextLink(
                    key: const ValueKey('log-in-instead'),
                    text: LangKeys.signupLogInInstead.tr,
                    chevron: true,
                    onTap: controller.onLogInInsteadTap,
                  ),
                ),
              ],
              const SizedBox(height: KnSize.space12),
              Focus(
                onFocusChange: (focused) {
                  if (!focused) controller.onPasswordDone();
                },
                child: KnCustomTextFormField(
                  fieldKey: const ValueKey('signup-password'),
                  label: LangKeys.loginPasswordLabel.tr,
                  controller: controller.passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: controller.onPasswordChanged,
                  onSubmitted: controller.onPasswordDone,
                  hasError: controller.passwordHasError,
                ),
              ),
              const SizedBox(height: KnSize.space12),
              PasswordStrength(
                weak: controller.passwordHasError,
                strength: controller.strength,
                rules: controller.rules,
                ok: controller.passwordStrong,
              ),
              const SizedBox(height: KnSize.space12),
              KnCheckboxTile(
                key: const ValueKey('signup-terms'),
                value: controller.agreed.value,
                label: LangKeys.signupTerms.tr,
                hasError: controller.showTermsError.value,
                onChanged: controller.onAgreeChanged,
              ),
              if (controller.showTermsError.value) KnInlineError(message: LangKeys.signupTermsMissing.tr),
              const SizedBox(height: KnSize.space24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ownerCard(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Row(
        children: [
          KnInitialsAvatar(initials: controller.initials),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(LangKeys.signupOwnerTitle.tr, style: text.label),
                const SizedBox(height: KnSize.space2),
                CustomBaseTextWidget(LangKeys.signupOwnerBody.tr, style: text.caption, color: kn.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
