import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

enum LogoutChoice { logout, sendFirst }

/// "Log out?" when [waiting] items are still on the phone (Figma 33:1552).
Future<LogoutChoice?> showLogoutDialog(int waiting) => Get.dialog<LogoutChoice>(
      Builder(
        builder: (context) {
          final kn = context.kn;
          final text = context.knText;
          return Dialog(
            backgroundColor: kn.bgSurface,
            insetPadding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KnSize.radiusXl)),
            child: Padding(
              padding: const EdgeInsets.all(KnSize.space24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CustomBaseTextWidget(LangKeys.meLogoutTitle.tr, style: text.h2),
                  const SizedBox(height: KnSize.space12),
                  CustomBaseTextWidget(
                    LangKeys.meLogoutWaiting.trParams({'n': '$waiting'}),
                    style: text.body,
                    color: kn.textSecondary,
                  ),
                  const SizedBox(height: KnSize.space24),
                  KnCustomButton(
                    key: const ValueKey('logout-anyway'),
                    text: LangKeys.meLogoutAnyway.tr,
                    icon: LucideIcons.logOut,
                    variant: KnButtonVariant.danger,
                    onTap: () => Get.back<LogoutChoice>(result: LogoutChoice.logout),
                  ),
                  const SizedBox(height: KnSize.space12),
                  KnCustomButton(
                    key: const ValueKey('logout-send-first'),
                    text: LangKeys.meSendFirst.tr,
                    icon: LucideIcons.cloud,
                    variant: KnButtonVariant.secondary,
                    onTap: () => Get.back<LogoutChoice>(result: LogoutChoice.sendFirst),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
