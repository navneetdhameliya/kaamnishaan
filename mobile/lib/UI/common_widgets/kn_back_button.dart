import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../infrastructure/lang/lang_keys.g.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// Round back button at the top-left of a screen.
class KnBackButton extends StatelessWidget {
  const KnBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return CustomInkWell(
      onTap: onTap ?? Get.back,
      borderRadius: BorderRadius.circular(KnSize.radiusFull),
      semanticLabel: LangKeys.commonBack.tr,
      child: Ink(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: kn.bgSurface,
          shape: BoxShape.circle,
          border: Border.all(color: kn.borderDefault),
        ),
        child: Icon(LucideIcons.chevronLeft, size: 22, color: kn.textPrimary),
      ),
    );
  }
}
