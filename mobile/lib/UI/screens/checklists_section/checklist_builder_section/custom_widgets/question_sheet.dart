import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_photo_source_sheet.dart';
import '../../../../common_widgets/kn_switch_row.dart';
import '../../../../common_widgets/kn_text_box.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../checklist_builder_controller.dart';

/// M26 Add question / Edit question (Figma 247:2404): the words, the answer type, a photo rule and a
/// reference photo showing what a good answer looks like.
class QuestionSheet extends StatelessWidget {
  const QuestionSheet({super.key, required this.controller});

  final ChecklistBuilderController controller;

  static IconData _icon(String type) => switch (type) {
        'yes_no' => LucideIcons.check,
        'pass_fail' => LucideIcons.listChecks,
        'number' => LucideIcons.slidersHorizontal,
        'photo' => LucideIcons.camera,
        _ => LucideIcons.pencil,
      };

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomBaseTextWidget(LangKeys.cbQuestion.tr, style: text.label),
            const SizedBox(height: KnSize.space8),
            KnTextBox(
              fieldKey: const ValueKey('question-text'),
              controller: controller.text,
              hint: LangKeys.cbQuestionHint.tr,
              minLines: 1,
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: KnSize.space16),
            CustomBaseTextWidget(LangKeys.cbAnswerType.tr, style: text.label),
            const SizedBox(height: KnSize.space8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in ChecklistBuilderController.types) ...[
                    _TypeCard(
                      key: ValueKey('type-$t'),
                      icon: _icon(t),
                      label: ChecklistBuilderController.typeLabel(t),
                      selected: controller.type.value == t,
                      enabled: !controller.typeLocked || controller.type.value == t,
                      onTap: () => controller.onType(t),
                    ),
                    const SizedBox(width: KnSize.space8),
                  ],
                ],
              ),
            ),
            if (controller.type.value == 'number') ...[
              const SizedBox(height: KnSize.space16),
              CustomBaseTextWidget(LangKeys.cbUnit.tr, style: text.label),
              const SizedBox(height: KnSize.space8),
              KnTextBox(
                fieldKey: const ValueKey('question-unit'),
                controller: controller.unit,
                hint: LangKeys.cbUnitHint.tr,
                minLines: 1,
                maxLines: 1,
                maxLength: 16,
              ),
            ],
            if (controller.showPhotoSwitch) ...[
              const SizedBox(height: KnSize.space8),
              KnSwitchRow(
                key: const ValueKey('question-photo'),
                title: controller.photoLabel,
                subtitle: LangKeys.cbPhotoSub.tr,
                value: controller.photo.value,
                onChanged: (v) => controller.photo.value = v,
                padding: const EdgeInsets.symmetric(vertical: KnSize.space12),
              ),
            ],
            const SizedBox(height: KnSize.space8),
            _ReferencePhoto(controller: controller),
            const SizedBox(height: KnSize.space16),
            Container(
              padding: const EdgeInsets.all(KnSize.space12),
              decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
              child: Row(
                children: [
                  Icon(LucideIcons.globe, size: 16, color: kn.textPrimary),
                  const SizedBox(width: KnSize.space8),
                  Expanded(child: CustomBaseTextWidget(LangKeys.cbTranslateNote.tr, style: text.labelSm)),
                ],
              ),
            ),
            const SizedBox(height: KnSize.space16),
            Row(
              children: [
                IntrinsicWidth(
                  child: KnCustomButton(
                    key: const ValueKey('question-save'),
                    text: controller.editing.value == null ? LangKeys.cbAdd.tr : LangKeys.cbSaveQ.tr,
                    icon: controller.editing.value == null ? LucideIcons.plus : LucideIcons.check,
                    loading: controller.busy.value,
                    enabled: controller.textDraft.value.trim().isNotEmpty,
                    onTap: () async {
                      if (await controller.onSaveQuestion()) Get.back<void>();
                    },
                  ),
                ),
                if (controller.editing.value != null) ...[
                  const SizedBox(width: KnSize.space8),
                  IntrinsicWidth(
                    child: KnCustomButton(
                      key: const ValueKey('question-delete'),
                      text: LangKeys.cbDeleteQ.tr,
                      icon: LucideIcons.trash2,
                      variant: KnButtonVariant.ghost,
                      onTap: () async {
                        if (await controller.onDeleteQuestion()) Get.back<void>();
                      },
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Reference photo": a thumbnail with Change / Remove, or a button to add one.
class _ReferencePhoto extends StatelessWidget {
  const _ReferencePhoto({required this.controller});

  final ChecklistBuilderController controller;

  Future<void> _pick() async {
    final source = await showKnPhotoSourceSheet(title: LangKeys.cbRef.tr);
    if (source != null) await controller.onPickReference(source);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    final picked = controller.referencePicked.value;
    const side = 72.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomBaseTextWidget(LangKeys.cbRef.tr, style: text.label),
        const SizedBox(height: KnSize.space4),
        CustomBaseTextWidget(LangKeys.cbRefHint.tr, style: text.labelSm, color: context.kn.textSecondary),
        const SizedBox(height: KnSize.space8),
        if (!controller.hasReference)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: IntrinsicWidth(
              child: KnCustomButton(
                key: const ValueKey('question-ref-add'),
                text: LangKeys.cbRefAdd.tr,
                icon: LucideIcons.imagePlus,
                variant: KnButtonVariant.secondary,
                onTap: _pick,
              ),
            ),
          )
        else
          Row(
            children: [
              ClipRRect(
                key: const ValueKey('question-ref-thumb'),
                borderRadius: BorderRadius.circular(KnSize.radiusMd),
                child: picked != null
                    ? Image.memory(picked.bytes, width: side, height: side, fit: BoxFit.cover)
                    : KnCoverImage(url: controller.referenceUrl.value, width: side, height: side, placeholderIcon: LucideIcons.image),
              ),
              const SizedBox(width: KnSize.space12),
              Flexible(
                child: Wrap(
                  spacing: KnSize.space8,
                  runSpacing: KnSize.space8,
                  children: [
                    IntrinsicWidth(
                      child: KnCustomButton(
                        key: const ValueKey('question-ref-change'),
                        text: LangKeys.cbRefChange.tr,
                        icon: LucideIcons.imagePlus,
                        variant: KnButtonVariant.secondary,
                        onTap: _pick,
                      ),
                    ),
                    IntrinsicWidth(
                      child: KnCustomButton(
                        key: const ValueKey('question-ref-remove'),
                        text: LangKeys.cbRefRemove.tr,
                        icon: LucideIcons.x,
                        variant: KnButtonVariant.ghost,
                        onTap: controller.onRemoveReference,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusMd);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: CustomInkWell(
        onTap: onTap,
        borderRadius: radius,
        semanticLabel: label,
        child: Ink(
          width: 108,
          padding: const EdgeInsets.symmetric(vertical: KnSize.space16, horizontal: KnSize.space8),
          decoration: BoxDecoration(
            color: selected ? kn.actionSecondary : kn.bgSurface,
            borderRadius: radius,
            border: Border.all(color: selected ? kn.textPrimary : kn.borderDefault, width: selected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: kn.textPrimary),
              const SizedBox(height: KnSize.space8),
              CustomBaseTextWidget(label, style: context.knText.labelSm, maxLines: 1, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
