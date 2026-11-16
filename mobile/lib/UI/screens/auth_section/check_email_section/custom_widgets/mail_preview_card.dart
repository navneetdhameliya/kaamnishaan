import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M08 picture of the email to look for: "KaamNishaan · Reset your password, from no-reply@…" (Figma "Email preview").
class MailPreviewCard extends StatelessWidget {
  const MailPreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: kn.actionPrimary, shape: BoxShape.circle),
            child: Icon(LucideIcons.mail, size: 20, color: kn.textOnAction),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(LangKeys.forgotMailSubject.tr, style: text.label),
                const SizedBox(height: KnSize.space2),
                CustomBaseTextWidget(LangKeys.forgotMailFrom.tr, style: text.caption, color: kn.textSecondary),
              ],
            ),
          ),
          const SizedBox(width: KnSize.space12),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: kn.actionPrimary, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}
