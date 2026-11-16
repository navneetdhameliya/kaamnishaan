import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_select_card.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'choose_company_controller.dart';

/// Choose company (not designed yet; uses the approved choice cards).
class ChooseCompanyScreen extends GetView<ChooseCompanyController> {
  const ChooseCompanyScreen({super.key});

  String _role(String role) => switch (role) {
        'owner' => LangKeys.roleOwner.tr,
        'manager' => LangKeys.roleManager.tr,
        _ => LangKeys.roleTechnician.tr,
      };

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    return KnPageScaffold(
      showBack: false,
      footer: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              text: LangKeys.commonContinue.tr,
              icon: LucideIcons.chevronRight,
              loading: controller.apiCallLoader.value,
              onTap: controller.callSwitchCompanyAPI,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KnSize.space32),
          CustomBaseTextWidget(LangKeys.companyChooseTitle.tr, style: text.h1),
          const SizedBox(height: KnSize.space4),
          CustomBaseTextWidget(LangKeys.companyChooseSubtitle.tr, style: text.bodyLg, color: context.kn.textSecondary),
          const SizedBox(height: KnSize.space24),
          Obx(
            () => Column(
              children: [
                for (final c in controller.session.companies) ...[
                  KnSelectCard(
                    title: c.name,
                    subtitle: _role(c.role),
                    selected: controller.selectedId.value == c.companyId,
                    onTap: () => controller.onCompanyTap(c.companyId),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
