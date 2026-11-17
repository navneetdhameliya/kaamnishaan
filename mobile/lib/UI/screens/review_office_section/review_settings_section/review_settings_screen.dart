import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_switch_row.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/settings_parts.dart';
import 'review_settings_controller.dart';

/// M46 Review settings (Figma 265:4595).
class ReviewSettingsScreen extends GetView<ReviewSettingsController> {
  const ReviewSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: Obx(() {
            final c = controller;
            return ListView(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                KnTitleBar(title: LangKeys.crevTitle.tr, subtitle: LangKeys.rsetSubtitle.tr),
                const SizedBox(height: KnSize.space16),
                if (!c.loaded)
                  const CommonShimmer(height: 380, radius: KnSize.radiusLg)
                else ...[
                  SettingsCard(
                    children: [
                      KnSwitchRow(
                        key: const ValueKey('rset-ask'),
                        title: LangKeys.rsetAsk.tr,
                        subtitle: LangKeys.rsetAskSub.tr,
                        value: c.askOnShare.value,
                        enabled: c.canEdit,
                        onChanged: (v) => c.toggle(c.askOnShare, v),
                      ),
                      KnSwitchRow(
                        key: const ValueKey('rset-remind'),
                        title: LangKeys.rsetRemind.tr,
                        subtitle: c.reminderSub,
                        value: c.reminderEnabled.value,
                        enabled: c.canEdit,
                        onChanged: (v) => c.toggle(c.reminderEnabled, v),
                      ),
                      KnSwitchRow(
                        key: const ValueKey('rset-low'),
                        title: LangKeys.rsetLow.tr,
                        subtitle: c.lowSub,
                        value: c.lowRatingAlert.value,
                        enabled: c.canEdit,
                        onChanged: (v) => c.toggle(c.lowRatingAlert, v),
                      ),
                      KnSwitchRow(
                        key: const ValueKey('rset-techs-see'),
                        title: LangKeys.rsetTechsSee.tr,
                        subtitle: LangKeys.rsetTechsSeeSub.tr,
                        value: c.techsSeeReviews.value,
                        enabled: c.canEdit,
                        onChanged: (v) => c.toggle(c.techsSeeReviews, v),
                      ),
                      KnSwitchRow(
                        key: const ValueKey('rset-public'),
                        title: LangKeys.rsetPublic.tr,
                        subtitle: LangKeys.rsetPublicSub.tr,
                        value: c.showPublicReviews.value,
                        enabled: c.canEdit,
                        onChanged: (v) => c.toggle(c.showPublicReviews, v),
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space12),
                  SettingsCard(
                    padding: const EdgeInsets.all(KnSize.space16),
                    children: [
                      CustomBaseTextWidget(LangKeys.rsetGoogle.tr, style: text.label),
                      const SizedBox(height: KnSize.space8),
                      TextField(
                        key: const ValueKey('rset-google'),
                        controller: c.googleUrl,
                        readOnly: !c.canEdit,
                        keyboardType: TextInputType.url,
                        style: text.bodyLg,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: kn.bgSurface,
                          hintText: 'g.page/r/…',
                          prefixIcon: Icon(LucideIcons.globe, size: 20, color: kn.textSecondary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(KnSize.radiusMd),
                            borderSide: BorderSide(color: kn.borderStrong),
                          ),
                        ),
                      ),
                      const SizedBox(height: KnSize.space8),
                      CustomBaseTextWidget(LangKeys.rsetGoogleHelp.tr, style: text.caption, color: kn.textSecondary),
                    ],
                  ),
                ],
              ],
            );
          }),
        ),
      ),
      bottomNavigationBar: SettingsSaveFooter(controller: controller),
    );
  }
}
