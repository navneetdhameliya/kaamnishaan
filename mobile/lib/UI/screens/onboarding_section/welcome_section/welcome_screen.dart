import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/commons/constants/image_constants.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_brand_mark.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'welcome_controller.dart';

/// M04 Welcome (Figma 15:936).
class WelcomeScreen extends GetView<WelcomeController> {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return KnPageScaffold(
      showBack: false,
      footer: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: KnSize.space24),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KnSize.space4,
            children: [
              CustomBaseTextWidget(LangKeys.welcomeHaveAccount.tr, style: text.body, color: kn.textSecondary),
              CustomInkWell(
                onTap: controller.onLogInTap,
                borderRadius: BorderRadius.circular(KnSize.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                  child: CustomBaseTextWidget(LangKeys.welcomeLogIn.tr, style: text.label, color: kn.textLink),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KnSize.space24),
          const KnBrandMark(size: 56),
          const SizedBox(height: KnSize.space16),
          CustomBaseTextWidget(LangKeys.welcomeTitle.tr, style: text.h1),
          const SizedBox(height: KnSize.space4),
          CustomBaseTextWidget(LangKeys.welcomeSubtitle.tr, style: text.bodyLg, color: kn.textSecondary),
          const SizedBox(height: KnSize.space24),
          // "I have an invite" — the main choice
          CustomInkWell(
            key: const ValueKey('welcome-invite'),
            onTap: controller.onInviteTap,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                color: kn.bgSurface,
                borderRadius: radius,
                border: Border.all(color: kn.actionPrimary, width: 2),
                boxShadow: KnShadow.md,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(KnSize.radiusLg - 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 140,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(ImageConstants.welcomeInvite, fit: BoxFit.cover),
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
                              decoration: BoxDecoration(
                                color: kn.bgSurface,
                                borderRadius: BorderRadius.circular(KnSize.radiusFull),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.phone, size: 14, color: kn.textPrimary),
                                  const SizedBox(width: 6),
                                  CustomBaseTextWidget(LangKeys.welcomeInviteTag.tr, style: text.labelSm),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(KnSize.space16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CustomBaseTextWidget(LangKeys.welcomeInviteTitle.tr, style: text.h3),
                                const SizedBox(height: KnSize.space2),
                                CustomBaseTextWidget(
                                  LangKeys.welcomeInviteBody.tr,
                                  style: text.body,
                                  color: kn.textSecondary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: KnSize.space12),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: kn.actionPrimary, shape: BoxShape.circle),
                            child: Icon(LucideIcons.chevronRight, size: 20, color: kn.textOnAction),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: KnSize.space12),
          // "Start my business"
          CustomInkWell(
            key: const ValueKey('welcome-business'),
            onTap: controller.onStartBusinessTap,
            borderRadius: radius,
            child: Ink(
              padding: const EdgeInsets.all(KnSize.space16),
              decoration: BoxDecoration(
                color: kn.bgSurface,
                borderRadius: radius,
                border: Border.all(color: kn.borderDefault),
                boxShadow: KnShadow.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: KnPrimitive.sage100,
                      borderRadius: BorderRadius.circular(KnSize.radiusMd),
                    ),
                    child: const Icon(LucideIcons.briefcase, size: 28, color: KnPrimitive.sage700),
                  ),
                  const SizedBox(width: KnSize.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBaseTextWidget(LangKeys.welcomeBusinessTitle.tr, style: text.h3),
                        const SizedBox(height: KnSize.space2),
                        CustomBaseTextWidget(LangKeys.welcomeBusinessBody.tr, style: text.body, color: kn.textSecondary),
                      ],
                    ),
                  ),
                  Icon(LucideIcons.chevronRight, size: 22, color: kn.textPrimary),
                ],
              ),
            ),
          ),
          const SizedBox(height: KnSize.space24),
        ],
      ),
    );
  }
}
