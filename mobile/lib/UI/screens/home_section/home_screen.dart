import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../infrastructure/commons/constants/app_routes.dart';
import '../../../infrastructure/lang/lang_keys.g.dart';
import '../../../infrastructure/services/session_service.dart';
import '../../common_widgets/kn_brand_mark.dart';
import '../../common_widgets/kn_custom_button.dart';
import '../../common_widgets/kn_page_scaffold.dart';
import '../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../theme/kn_app_theme.dart';
import '../../theme/kn_tokens.g.dart';

/// Temporary landing screen after login. Replaced by M12 Today / M13 Dashboard in Step 2c.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _logout() async {
    await Get.find<SessionService>().logout();
    Get.offAllNamed(RoutesConstants.welcomeScreen);
  }

  @override
  Widget build(BuildContext context) {
    final name = Get.find<SessionService>().me.value?.name ?? '';
    return KnPageScaffold(
      showBack: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KnSize.space48),
          const KnBrandMark(size: 56),
          const SizedBox(height: KnSize.space16),
          CustomBaseTextWidget(LangKeys.homeHello.trParams({'name': name}), style: context.knText.h1),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(LangKeys.homeComingSoon.tr, style: context.knText.bodyLg, color: context.kn.textSecondary),
          const SizedBox(height: KnSize.space32),
          KnCustomButton(
            text: LangKeys.commonLogOut.tr,
            icon: LucideIcons.logOut,
            variant: KnButtonVariant.secondary,
            onTap: _logout,
          ),
        ],
      ),
    );
  }
}
