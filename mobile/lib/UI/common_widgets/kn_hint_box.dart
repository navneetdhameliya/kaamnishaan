import 'package:flutter/material.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';

/// A soft info box ("We fill the code for you when the SMS comes.").
class KnHintBox extends StatelessWidget {
  const KnHintBox({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: KnSize.space8),
      decoration: BoxDecoration(color: kn.statusInfoBg, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kn.statusInfo),
          const SizedBox(width: KnSize.space8),
          Expanded(child: CustomBaseTextWidget(text, style: context.knText.caption, color: kn.textPrimary)),
        ],
      ),
    );
  }
}
