import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_page_scaffold.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// A tab whose screens come in a later step (Jobs M14, Reports M30): its name and a short note.
class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return KnPageScaffold(
      showBack: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KnSize.space48),
          CustomBaseTextWidget(title, style: context.knText.h1),
          const SizedBox(height: KnSize.space24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: kn.textSecondary),
          ),
          const SizedBox(height: KnSize.space16),
          CustomBaseTextWidget(LangKeys.commonComingSoon.tr, style: context.knText.bodyLg, color: kn.textSecondary),
          const SizedBox(height: 112),
        ],
      ),
    );
  }
}
