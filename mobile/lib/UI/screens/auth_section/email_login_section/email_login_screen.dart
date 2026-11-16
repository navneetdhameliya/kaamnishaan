import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_custom_text_form_field.dart';
import '../../../common_widgets/kn_text_link.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/locked_banner.dart';
import 'custom_widgets/login_header.dart';
import 'email_login_controller.dart';

/// M06 Email login (Figma 39:636; wrong password 75:1308; invalid email 75:1383; locked 75:1460).
class EmailLoginScreen extends GetView<EmailLoginController> {
  const EmailLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final insets = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kn.bgCanvas,
        body: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    LoginHeader(top: insets.top),
                    Padding(
                      padding: EdgeInsets.fromLTRB(KnSize.space16, insets.top + 220, KnSize.space16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _card(context),
                          const SizedBox(height: 20),
                          _alternatives(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(KnSize.space16, KnSize.space24, KnSize.space16, insets.bottom + 24),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: KnTextLink(
                      key: const ValueKey('create-account'),
                      text: LangKeys.loginNewHere.tr,
                      large: true,
                      textAlign: TextAlign.center,
                      onTap: controller.onCreateAccountTap,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final kn = context.kn;
    return Container(
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
        boxShadow: KnShadow.md,
      ),
      child: AutofillGroup(
        child: Obx(() {
          final locked = controller.isLocked;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (locked) ...[
                LockedBanner(
                  minutes: controller.lockedMinutes,
                  time: controller.lockedTime,
                  tries: EmailLoginController.maxTries,
                  onReset: controller.onForgotTap,
                ),
                const SizedBox(height: KnSize.space12),
              ],
              Focus(
                onFocusChange: (focused) {
                  if (!focused) controller.onEmailDone();
                },
                child: KnCustomTextFormField(
                  fieldKey: const ValueKey('login-email'),
                  label: LangKeys.loginEmailLabel.tr,
                  controller: controller.emailController,
                  readOnly: locked,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email, AutofillHints.username],
                  onChanged: controller.onEmailChanged,
                  onSubmitted: controller.onEmailDone,
                  errorText: controller.emailError,
                  onHearError: controller.onHearEmailErrorTap,
                ),
              ),
              const SizedBox(height: KnSize.space12),
              KnCustomTextFormField(
                fieldKey: const ValueKey('login-password'),
                label: LangKeys.loginPasswordLabel.tr,
                controller: controller.passwordController,
                readOnly: locked,
                obscureText: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onChanged: controller.onPasswordChanged,
                onSubmitted: (_) => controller.callLoginAPI(),
                errorText: controller.passwordError,
                onHearError: controller.onHearPasswordErrorTap,
              ),
              if (!locked) ...[
                const SizedBox(height: KnSize.space12),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: KnTextLink(
                    key: const ValueKey('forgot-password'),
                    text: controller.attemptsLeft.value != null ? LangKeys.loginForgotReset.tr : LangKeys.loginForgot.tr,
                    onTap: controller.onForgotTap,
                  ),
                ),
              ],
              const SizedBox(height: KnSize.space12),
              KnCustomButton(
                key: const ValueKey('log-in'),
                text: LangKeys.loginButton.tr,
                enabled: controller.canSubmit,
                loading: controller.apiCallLoader.value,
                onTap: controller.callLoginAPI,
                onDisabledTap: controller.onDisabledLoginTap,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _alternatives(BuildContext context) {
    final kn = context.kn;
    Widget line() => Expanded(child: Container(height: 1, color: kn.borderDefault));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            line(),
            const SizedBox(width: KnSize.space12),
            CustomBaseTextWidget(LangKeys.loginOr.tr, style: context.knText.caption, color: kn.textSecondary),
            const SizedBox(width: KnSize.space12),
            line(),
          ],
        ),
        const SizedBox(height: KnSize.space16),
        KnCustomButton(
          key: const ValueKey('phone-login'),
          text: LangKeys.loginWithPhone.tr,
          icon: LucideIcons.phone,
          variant: KnButtonVariant.secondary,
          onTap: controller.onPhoneLoginTap,
        ),
      ],
    );
  }
}
