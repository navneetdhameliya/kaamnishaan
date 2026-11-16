import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_loader.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_inline_error.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/join_widgets.dart';
import 'join_company_controller.dart';

/// M10 Join company (Figma 16:896; invite expired 73:2209). Also the "no invite" case.
class JoinCompanyScreen extends GetView<JoinCompanyController> {
  const JoinCompanyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return switch (controller.state.value) {
        JoinState.loading => KnPageScaffold(onBack: controller.onBackTap, body: const SizedBox(height: 300, child: CommonLoader())),
        JoinState.invite => _invite(context),
        JoinState.expired => _problem(context, expired: true),
        JoinState.none => _problem(context, expired: false),
      };
    });
  }

  Widget _invite(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final inv = controller.invite.value!;
    return KnPageScaffold(
      onBack: controller.onBackTap,
      footer: KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('join-company'),
            text: LangKeys.joinJoinButton.tr,
            icon: LucideIcons.check,
            loading: controller.apiCallLoader.value,
            onTap: controller.callAcceptInviteAPI,
          ),
          KnCustomButton(
            text: LangKeys.joinNotMine.tr,
            variant: KnButtonVariant.ghost,
            onTap: controller.callDeclineInviteAPI,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: KnSize.space8),
          CompanyLogo(name: inv.company.name, logoUrl: inv.company.logoUrl),
          const SizedBox(height: KnSize.space16),
          CustomBaseTextWidget(
            LangKeys.joinTitle.trParams({'company': controller.companyName}),
            style: text.h1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KnSize.space4),
          CustomBaseTextWidget(controller.companyMeta, style: text.body, color: kn.textSecondary),
          const SizedBox(height: KnSize.space16),
          JoinCard(
            child: InviterRow(
              title: LangKeys.joinInvitedYou.trParams({'name': controller.managerName}),
              subtitle: controller.sentAgo,
            ),
          ),
          const SizedBox(height: KnSize.space12),
          JoinCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(LangKeys.joinWhenYouJoin.tr, style: text.label),
                BenefitRow(
                  icon: LucideIcons.briefcase,
                  text: LangKeys.joinBenefitJobs.trParams({'company': controller.companyName}),
                ),
                BenefitRow(icon: LucideIcons.camera, text: LangKeys.joinBenefitPhotos.tr),
                BenefitRow(icon: LucideIcons.fileText, text: LangKeys.joinBenefitReports.tr),
              ],
            ),
          ),
          const SizedBox(height: KnSize.space16),
        ],
      ),
    );
  }

  /// Expired / cancelled invite, or no invite at all for this number.
  Widget _problem(BuildContext context, {required bool expired}) {
    final kn = context.kn;
    final text = context.knText;
    final inv = controller.invite.value;
    return KnPageScaffold(
      onBack: controller.onBackTap,
      footer: KnScreenFooter(
        children: [
          if (expired && controller.canCallManager)
            KnCustomButton(
              text: LangKeys.joinCallManager.tr,
              icon: LucideIcons.phone,
              onTap: controller.onCallManagerTap,
            ),
          KnCustomButton(
            key: const ValueKey('join-try-again'),
            text: LangKeys.commonRetry.tr,
            icon: LucideIcons.rotateCw,
            variant: expired && controller.canCallManager ? KnButtonVariant.secondary : KnButtonVariant.primary,
            onTap: controller.onTryAgainTap,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: KnSize.space8),
          CompanyLogo(name: inv?.company.name ?? '?', logoUrl: inv?.company.logoUrl, faded: true, alert: true),
          const SizedBox(height: KnSize.space16),
          CustomBaseTextWidget(
            expired ? LangKeys.joinExpiredTitle.tr : LangKeys.joinNoInviteTitle.tr,
            style: text.h1,
            textAlign: TextAlign.center,
          ),
          if (inv != null) ...[
            const SizedBox(height: KnSize.space4),
            CustomBaseTextWidget(
              [controller.companyName, controller.companyMeta].where((s) => s.isNotEmpty).join(' · '),
              style: text.body,
              color: kn.textSecondary,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: KnSize.space16),
          if (expired && inv != null) ...[
            JoinCard(
              child: InviterRow(
                title: LangKeys.joinInvitedYou.trParams({'name': controller.managerName}),
                subtitle: controller.sentAgo,
                onCall: controller.canCallManager ? controller.onCallManagerTap : null,
              ),
            ),
            const SizedBox(height: KnSize.space12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(KnSize.space12),
              color: kn.statusDangerBg,
              child: KnInlineError(message: LangKeys.joinExpiredBody.trParams({'date': controller.expiredOn})),
            ),
            const SizedBox(height: KnSize.space12),
          ],
          JoinCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
                      child: Icon(LucideIcons.user, size: 18, color: kn.textPrimary),
                    ),
                    const SizedBox(width: KnSize.space12),
                    Expanded(child: CustomBaseTextWidget(LangKeys.joinAskManager.tr, style: text.label)),
                  ],
                ),
                const SizedBox(height: KnSize.space8),
                CustomBaseTextWidget(
                  expired
                      ? LangKeys.joinAskManagerBody.trParams({'name': controller.managerName})
                      : LangKeys.joinNoInviteBody.tr,
                  style: text.caption,
                  color: kn.textSecondary,
                ),
                const SizedBox(height: KnSize.space8),
                KnHearItButton(onTap: controller.onHearTap, danger: false),
              ],
            ),
          ),
          const SizedBox(height: KnSize.space16),
        ],
      ),
    );
  }
}
