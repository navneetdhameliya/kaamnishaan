import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_text_link.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M06 "Locked for 15 minutes · 5 wrong tries. Try again at 10:42 AM. · Reset password ›" (Figma 75:2083).
class LockedBanner extends StatelessWidget {
  const LockedBanner({super.key, required this.minutes, required this.time, required this.tries, required this.onReset});

  final int minutes;
  final String time;
  final int tries;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      key: const ValueKey('locked-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.statusDangerBg,
        borderRadius: BorderRadius.circular(KnSize.radiusMd),
        border: Border.all(color: kn.statusDanger),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.lock, size: 18, color: kn.statusDanger),
              const SizedBox(width: KnSize.space8),
              Expanded(
                child: CustomBaseTextWidget(
                  LangKeys.loginLockedTitle.trParams({'minutes': '$minutes'}),
                  style: text.label,
                  color: kn.statusDanger,
                ),
              ),
            ],
          ),
          const SizedBox(height: KnSize.space4),
          CustomBaseTextWidget(
            LangKeys.loginLockedBody.trParams({'count': '$tries', 'time': time}),
            style: text.caption,
          ),
          const SizedBox(height: KnSize.space4),
          KnTextLink(text: LangKeys.loginResetPassword.tr, chevron: true, onTap: onReset),
        ],
      ),
    );
  }
}
