import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../infrastructure/lang/lang_keys.g.dart';
import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'kn_custom_button.dart';

/// "Remove Asha from the team?" with the action and "Keep" (like the Log out dialog, Figma 33:1552).
/// True when the person chose the action. [danger] paints it red.
Future<bool> showKnConfirmDialog({
  required String title,
  required String body,
  required String action,
  IconData icon = LucideIcons.check,
  bool danger = false,
}) async =>
    await Get.dialog<bool>(
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
                  CustomBaseTextWidget(title, style: text.h2),
                  const SizedBox(height: KnSize.space12),
                  CustomBaseTextWidget(body, style: text.body, color: kn.textSecondary),
                  const SizedBox(height: KnSize.space24),
                  KnCustomButton(
                    key: const ValueKey('confirm-yes'),
                    text: action,
                    icon: icon,
                    variant: danger ? KnButtonVariant.danger : KnButtonVariant.primary,
                    onTap: () => Get.back<bool>(result: true),
                  ),
                  const SizedBox(height: KnSize.space12),
                  KnCustomButton(
                    key: const ValueKey('confirm-no'),
                    text: LangKeys.commonKeep.tr,
                    variant: KnButtonVariant.secondary,
                    onTap: () => Get.back<bool>(result: false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ) ==
    true;
