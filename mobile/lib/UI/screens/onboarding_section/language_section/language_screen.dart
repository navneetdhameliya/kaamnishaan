import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../common_widgets/kn_brand_mark.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_select_card.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'language_controller.dart';

/// M02 Language selection (Figma 15:809).
class LanguageScreen extends GetView<LanguageController> {
  const LanguageScreen({super.key});

  TextStyle _nameStyle(String code) => switch (code) {
        'hi' => KnText.hindi.h3,
        'gu' => KnText.gujarati.h3,
        _ => KnText.latin.h3,
      };

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return KnPageScaffold(
      showBack: false,
      footer: KnScreenFooter(
        children: [
          KnCustomButton(
            text: LangKeys.commonContinue.tr,
            icon: LucideIcons.chevronRight,
            onTap: controller.onContinueTap,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: KnSize.space16),
          const KnBrandMark(size: 48),
          const SizedBox(height: KnSize.space16),
          CustomBaseTextWidget(LangKeys.languageTitle.tr, style: context.knText.h1),
          const SizedBox(height: KnSize.space4),
          Row(
            children: [
              Icon(LucideIcons.volume2, size: 18, color: kn.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: CustomBaseTextWidget(LangKeys.languageHint.tr, style: context.knText.body, color: kn.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: KnSize.space24),
          Obx(
            () => Column(
              children: [
                for (final lang in TranslationService.languages) ...[
                  KnSelectCard(
                    key: ValueKey('lang-${lang.code}'),
                    title: lang.nativeName,
                    subtitle: lang.english,
                    titleStyle: _nameStyle(lang.code),
                    selected: controller.selectedCode.value == lang.code,
                    onTap: () => controller.onLanguageTap(lang.code),
                    onSpeak: () => controller.onSpeakerTap(lang),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: KnSize.space16),
        ],
      ),
    );
  }
}
