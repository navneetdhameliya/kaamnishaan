import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_text_box.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../../../jobs_section/job_list_section/custom_widgets/job_list_parts.dart';
import '../checklist_builder_controller.dart';

/// M26 Translations: pick a language, then each question shows its words, the translation in a box, and
/// whether it is ready, made automatically (check it) or missing (type it). Saving makes it ready.
class TranslationsSheet extends StatelessWidget {
  const TranslationsSheet({super.key, required this.controller});

  final ChecklistBuilderController controller;

  static String languageName(String code) => switch (code) {
        'hi' => LangKeys.langHi.tr,
        'gu' => LangKeys.langGu.tr,
        'es' => LangKeys.langEs.tr,
        'fr' => LangKeys.langFr.tr,
        _ => LangKeys.langEn.tr,
      };

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Obx(() {
      final lang = controller.trLanguage.value;
      final qs = controller.questions;
      final left = controller.toCheck(lang);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: KnSize.space8,
            runSpacing: KnSize.space8,
            children: [
              for (final l in controller.otherLanguages)
                JobFilterChip(
                  key: ValueKey('tr-lang-$l'),
                  label: controller.toCheck(l) == 0 ? '${languageName(l)} ✓' : '${languageName(l)} · ${controller.toCheck(l)}',
                  selected: l == lang,
                  onTap: () => controller.onTrLanguage(l),
                ),
            ],
          ),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(
            left == 0 ? LangKeys.cbTrAllReady.tr : LangKeys.cbTrLeft.trParams({'n': '$left'}),
            key: const ValueKey('tr-left'),
            style: context.knText.labelSm,
            color: left == 0 ? kn.statusSuccess : kn.textSecondary,
          ),
          const SizedBox(height: KnSize.space12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: qs.length,
              separatorBuilder: (_, _) => const SizedBox(height: KnSize.space12),
              itemBuilder: (_, i) => _TrCard(
                key: ValueKey('tr-${qs[i].id}-$lang'),
                number: i + 1,
                question: qs[i],
                controller: controller,
                lang: lang,
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _TrCard extends StatelessWidget {
  const _TrCard({
    super.key,
    required this.number,
    required this.question,
    required this.controller,
    required this.lang,
  });

  final int number;
  final TemplateQuestionOutModel question;
  final ChecklistBuilderController controller;
  final String lang;

  @override
  Widget build(BuildContext context) => Obx(() => _build(context));

  Widget _build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final status = ChecklistBuilderController.trStatus(question, lang);
    final (label, color, bg, icon) = switch (status) {
      'ready' => (LangKeys.cbTrReadyOne.tr, kn.statusSuccess, kn.statusSuccessBg, LucideIcons.check),
      'needs_review' => (LangKeys.cbTrCheck.tr, kn.statusWarning, kn.statusWarningBg, LucideIcons.sparkles),
      _ => (LangKeys.cbTrMissing.tr, kn.statusDanger, kn.statusDangerBg, LucideIcons.circleAlert),
    };
    final box = controller.trBoxes[question.id];
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgCanvas,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CustomBaseTextWidget('$number. ${question.text}', style: text.label, maxLines: 4),
              ),
              const SizedBox(width: KnSize.space8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: KnSize.space8, vertical: 4),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: KnSize.space4),
                    CustomBaseTextWidget(label, style: text.caption, color: color),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KnSize.space8),
          if (box != null)
            KnTextBox(
              fieldKey: ValueKey('tr-box-${question.id}'),
              controller: box,
              hint: LangKeys.cbTrHint.trParams({'lang': TranslationsSheet.languageName(lang)}),
              minLines: 1,
              maxLines: 4,
              maxLength: 300,
            ),
          const SizedBox(height: KnSize.space8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IntrinsicWidth(
              child: KnCustomButton(
                key: ValueKey('tr-save-${question.id}'),
                text: status == 'needs_review' ? LangKeys.cbTrLooksRight.tr : LangKeys.cbTrSave.tr,
                icon: LucideIcons.check,
                variant: status == 'ready' ? KnButtonVariant.ghost : KnButtonVariant.secondary,
                loading: controller.trSaving.value == question.id,
                onTap: () => controller.onSaveTranslation(question),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
