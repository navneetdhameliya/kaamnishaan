import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'language_settings_controller.dart';

/// M38 Language settings (Figma 33:1644).
class LanguageSettingsScreen extends GetView<LanguageSettingsController> {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          Obx(
            () => KnCustomButton(
              key: const ValueKey('language-save'),
              text: LangKeys.commonSave.tr,
              icon: LucideIcons.check,
              loading: controller.saving.value,
              onTap: controller.onSaveTap,
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
            children: [
              Row(
                children: [
                  const KnBackButton(),
                  const SizedBox(width: KnSize.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBaseTextWidget(LangKeys.langTitle.tr, style: text.h3),
                        CustomBaseTextWidget(LangKeys.langSubtitle.tr, style: text.caption, color: kn.textSecondary),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: KnSize.space16),
              CustomBaseTextWidget(LangKeys.langApp.tr, style: text.label),
              const SizedBox(height: KnSize.space8),
              Container(
                decoration: BoxDecoration(
                  color: kn.bgSurface,
                  borderRadius: BorderRadius.circular(KnSize.radiusLg),
                  border: Border.all(color: kn.borderDefault),
                ),
                clipBehavior: Clip.antiAlias,
                child: Obx(
                  () => Column(
                    children: [
                      for (final (i, l) in controller.languages.indexed) ...[
                        if (i > 0) Divider(height: 1, color: kn.borderDefault),
                        CustomInkWell(
                          key: ValueKey('setting-lang-${l.code}'),
                          onTap: () => controller.onLanguageTap(l.code),
                          semanticLabel: l.english,
                          child: Container(
                            color: controller.selected.value == l.code ? kn.actionSecondary : null,
                            padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CustomBaseTextWidget(l.nativeName, style: KnText.forLocale(l.locale).label),
                                      CustomBaseTextWidget(l.english, style: text.caption, color: kn.textSecondary),
                                    ],
                                  ),
                                ),
                                _Radio(selected: controller.selected.value == l.code),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KnSize.space24),
              CustomBaseTextWidget(LangKeys.langReports.tr, style: text.label),
              const SizedBox(height: KnSize.space8),
              Container(
                key: const ValueKey('report-language'),
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
                decoration: BoxDecoration(
                  color: kn.bgSurface,
                  borderRadius: BorderRadius.circular(KnSize.radiusMd),
                  border: Border.all(color: kn.borderStrong),
                ),
                child: Row(
                  children: [
                    Expanded(child: CustomBaseTextWidget(controller.reportLanguage, style: text.body)),
                    Icon(LucideIcons.lock, size: 18, color: kn.textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: KnSize.space8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.mic, size: 14, color: kn.textSecondary),
                  ),
                  const SizedBox(width: KnSize.space8),
                  Expanded(
                    child: CustomBaseTextWidget(
                      '${LangKeys.langReportsNote.tr} ${LangKeys.langReportsOwner.tr}',
                      style: text.caption,
                      color: kn.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? kn.textPrimary : kn.borderStrong, width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: kn.textPrimary))
          : null,
    );
  }
}
