import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../../../jobs_section/job_list_section/custom_widgets/job_list_parts.dart';
import '../checklist_builder_controller.dart';

/// M26 Preview: the checklist as a technician meets it. Tapping an answer shows the questions that wait for
/// it ("show only if"), so the office can try the rules before saving. Nothing is saved.
class PreviewSheet extends StatelessWidget {
  const PreviewSheet({super.key, required this.controller});

  final ChecklistBuilderController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Obx(() {
      final qs = controller.previewQuestions;
      final number = {for (var i = 0; i < qs.length; i++) qs[i].id: i + 1};
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomBaseTextWidget(
            controller.previewCount,
            key: const ValueKey('preview-count'),
            style: context.knText.labelSm,
            color: kn.textSecondary,
          ),
          const SizedBox(height: KnSize.space12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: qs.length,
              separatorBuilder: (_, _) => const SizedBox(height: KnSize.space8),
              itemBuilder: (_, i) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _PreviewCard(
                  key: ValueKey('preview-${qs[i].id}'),
                  number: number[qs[i].id]!,
                  question: qs[i],
                  answer: controller.previewAnswers[qs[i].id],
                  onAnswer: (key) => controller.onPreviewAnswer(qs[i], key),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    super.key,
    required this.number,
    required this.question,
    required this.answer,
    required this.onAnswer,
  });

  final int number;
  final TemplateQuestionOutModel question;
  final String? answer;
  final ValueChanged<String> onAnswer;

  /// What the technician gives for a question that has no answers to tap.
  String _kind() => switch (question.type) {
        'number' => question.unit == null
            ? LangKeys.cbTNumber.tr
            : '${LangKeys.cbTNumber.tr} · ${question.unit}',
        'photo' => LangKeys.cbTPhoto.tr,
        'signature' => LangKeys.cbTSignature.tr,
        _ => LangKeys.cbPreviewWords.tr,
      };

  IconData _icon() => switch (question.type) {
        'number' => LucideIcons.slidersHorizontal,
        'photo' => LucideIcons.camera,
        'signature' => LucideIcons.pencil,
        _ => LucideIcons.mic,
      };

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final tappable = ChecklistBuilderController.ruleTypes.contains(question.type);
    final photo = switch (question.photoRule) {
      'if_no' => LangKeys.cbPhotoIfNo.tr,
      'if_fail' => LangKeys.cbPhotoIfFail.tr,
      'always' when question.type != 'photo' => LangKeys.cbPhotoAlways.tr,
      _ => null,
    };
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
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: kn.actionSecondary, shape: BoxShape.circle),
                child: CustomBaseTextWidget('$number', style: text.labelSm),
              ),
              const SizedBox(width: KnSize.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomBaseTextWidget(question.text, style: text.label, maxLines: 4),
                    if (!question.requiredValue)
                      CustomBaseTextWidget(LangKeys.cbOptional.tr, style: text.caption, color: kn.textSecondary),
                  ],
                ),
              ),
              if (question.referenceImageUrl != null) ...[
                const SizedBox(width: KnSize.space8),
                KnCoverImage(
                  url: question.referenceImageUrl,
                  width: 48,
                  height: 48,
                  radius: KnSize.radiusMd,
                  placeholderIcon: LucideIcons.image,
                ),
              ],
            ],
          ),
          const SizedBox(height: KnSize.space12),
          if (tappable)
            Wrap(
              spacing: KnSize.space8,
              runSpacing: KnSize.space8,
              children: [
                for (final (key, label) in ChecklistBuilderController.answers(question))
                  JobFilterChip(
                    key: ValueKey('preview-${question.id}-$key'),
                    label: label,
                    selected: answer == key,
                    onTap: () => onAnswer(key),
                  ),
              ],
            )
          else
            Row(
              children: [
                Icon(_icon(), size: 18, color: kn.textSecondary),
                const SizedBox(width: KnSize.space8),
                Expanded(child: CustomBaseTextWidget(_kind(), style: text.body, color: kn.textSecondary)),
              ],
            ),
          if (photo != null) ...[
            const SizedBox(height: KnSize.space8),
            Row(
              children: [
                Icon(LucideIcons.camera, size: 16, color: kn.statusWarning),
                const SizedBox(width: KnSize.space4),
                Expanded(child: CustomBaseTextWidget(photo, style: text.labelSm, color: kn.statusWarning)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
