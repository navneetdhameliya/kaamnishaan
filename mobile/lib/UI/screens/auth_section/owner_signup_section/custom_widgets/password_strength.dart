import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../owner_signup_controller.dart';

/// Under the password field. Normally one line ("✓ At least 8 characters"); when the password is weak,
/// the strength bars and each rule as "Missing: …" or "Done: …" (Figma 76:1986).
class PasswordStrength extends StatelessWidget {
  const PasswordStrength({super.key, required this.weak, required this.strength, required this.rules, required this.ok});

  /// Show the bars and rules.
  final bool weak;

  /// 0–3 rules met.
  final int strength;
  final List<PasswordRule> rules;

  /// The password is long enough (the single hint line turns green).
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    if (!weak) {
      final color = ok ? kn.statusSuccess : kn.textSecondary;
      return Row(
        children: [
          Icon(LucideIcons.check, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(child: CustomBaseTextWidget(LangKeys.signupPasswordHint.tr, style: text.caption, color: color)),
        ],
      );
    }
    return Column(
      key: const ValueKey('password-rules'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: KnSize.space4),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i < strength ? kn.statusDanger : kn.borderDefault,
                    borderRadius: BorderRadius.circular(KnSize.radiusFull),
                  ),
                ),
              ),
            ],
            const SizedBox(width: KnSize.space8),
            Icon(LucideIcons.circleAlert, size: 16, color: kn.statusDanger),
            const SizedBox(width: KnSize.space8),
            CustomBaseTextWidget(LangKeys.signupPasswordWeak.tr, style: text.labelSm, color: kn.statusDanger),
          ],
        ),
        const SizedBox(height: KnSize.space12),
        for (var i = 0; i < rules.length; i++) ...[
          if (i > 0) const SizedBox(height: KnSize.space4),
          Row(
            children: [
              Icon(
                rules[i].met ? LucideIcons.check : LucideIcons.x,
                size: 16,
                color: rules[i].met ? kn.statusSuccess : kn.statusDanger,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: CustomBaseTextWidget(
                  (rules[i].met ? LangKeys.signupRuleDone : LangKeys.signupRuleMissing).trParams({'rule': rules[i].label}),
                  style: text.captionStrong,
                  color: rules[i].met ? kn.statusSuccess : kn.statusDanger,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
