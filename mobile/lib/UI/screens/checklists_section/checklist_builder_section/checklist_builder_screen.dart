import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_dashed_border.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_text_box.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../../me_section/me_section/custom_widgets/me_rows.dart';
import 'checklist_builder_controller.dart';
import 'custom_widgets/question_sheet.dart';

/// M26 Checklist builder (Figma 247:2300; add question 247:2404).
class ChecklistBuilderScreen extends GetView<ChecklistBuilderController> {
  const ChecklistBuilderScreen({super.key});

  void _question({bool edit = false}) {
    showKnBottomSheet<void>(
      title: edit ? LangKeys.cbEdit.tr : LangKeys.cbAdd.tr,
      child: QuestionSheet(controller: controller),
    );
  }

  void _rename() {
    controller.startRename();
    showKnBottomSheet<void>(
      title: LangKeys.cbRename.tr,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(Get.context!).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KnTextBox(
              fieldKey: const ValueKey('checklist-rename'),
              controller: controller.rename,
              hint: LangKeys.cbNameHint.tr,
              minLines: 1,
              maxLines: 2,
              maxLength: 120,
            ),
            const SizedBox(height: KnSize.space16),
            KnCustomButton(
              text: LangKeys.commonSave.tr,
              onTap: () async {
                if (await controller.onRename()) Get.back<void>();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _menu() {
    showKnBottomSheet<void>(
      title: LangKeys.cbMenu.tr,
      child: MeCard(
        rows: [
          MeRow(
            key: const ValueKey('checklist-menu-rename'),
            icon: LucideIcons.pencil,
            label: LangKeys.cbRename.tr,
            onTap: () {
              Get.back<void>();
              _rename();
            },
          ),
          MeRow(
            key: const ValueKey('checklist-menu-archive'),
            icon: controller.archived ? LucideIcons.rotateCcw : LucideIcons.x,
            label: controller.archived ? LangKeys.cbUnarchive.tr : LangKeys.cbArchive.tr,
            onTap: () {
              Get.back<void>();
              controller.onArchiveTap();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: Obx(() {
            final t = controller.template.value;
            final qs = controller.questions;
            final header = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const KnBackButton(),
                    const SizedBox(width: KnSize.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(controller.name, style: text.h3, maxLines: 2),
                          CustomBaseTextWidget(controller.subtitle, style: text.caption, color: kn.textSecondary),
                        ],
                      ),
                    ),
                    if (controller.editable) ...[
                      const SizedBox(width: KnSize.space12),
                      CustomInkWell(
                        key: const ValueKey('checklist-menu'),
                        onTap: _menu,
                        borderRadius: BorderRadius.circular(KnSize.radiusFull),
                        semanticLabel: LangKeys.cbMenu.tr,
                        child: Ink(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: kn.bgSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: kn.borderDefault),
                          ),
                          child: Icon(LucideIcons.ellipsis, size: 22, color: kn.textPrimary),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: KnSize.space16),
                if (t == null)
                  const CommonShimmer(height: 300, radius: KnSize.radiusLg)
                else ...[
                  _Banner(
                    icon: controller.editable ? LucideIcons.globe : LucideIcons.lock,
                    label: controller.editable ? controller.translations : LangKeys.cbReadOnly.tr,
                    good: controller.editable && controller.languagesReady == ChecklistBuilderController.languages.length,
                    done: controller.editable && controller.languagesReady == ChecklistBuilderController.languages.length,
                  ),
                  if (controller.editable && (controller.draft || controller.archived)) ...[
                    const SizedBox(height: KnSize.space8),
                    CustomBaseTextWidget(
                      controller.draft ? LangKeys.cbDraftNote.tr : LangKeys.cbArchivedToast.tr,
                      style: text.caption,
                      color: kn.statusWarning,
                    ),
                  ],
                  const SizedBox(height: KnSize.space12),
                  if (qs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: KnSize.space24),
                      child: Column(
                        children: [
                          CustomBaseTextWidget(LangKeys.cbEmpty.tr, style: text.h3, textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          CustomBaseTextWidget(
                            LangKeys.cbEmptyBody.tr,
                            style: text.body,
                            color: kn.textSecondary,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            );
            final footer = t == null || !controller.editable
                ? const SizedBox(height: KnSize.space24)
                : Padding(
                    padding: const EdgeInsets.only(top: KnSize.space4, bottom: KnSize.space24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: KnDashedBorder(
                        color: kn.borderStrong,
                        radius: KnSize.radiusMd,
                        child: CustomInkWell(
                          key: const ValueKey('question-add'),
                          onTap: () {
                            controller.startAdd();
                            _question();
                          },
                          borderRadius: BorderRadius.circular(KnSize.radiusMd),
                          semanticLabel: LangKeys.cbAdd.tr,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: KnSize.space12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.plus, size: 20, color: kn.textPrimary),
                                const SizedBox(width: KnSize.space8),
                                CustomBaseTextWidget(LangKeys.cbAdd.tr, style: text.label),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
            return ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, 0),
              buildDefaultDragHandles: false,
              header: header,
              footer: footer,
              itemCount: qs.length,
              onReorder: controller.onReorder,
              proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
              itemBuilder: (context, i) {
                final q = qs[i];
                return Padding(
                  key: ValueKey('question-${q.id}'),
                  padding: const EdgeInsets.only(bottom: KnSize.space8),
                  child: _QuestionCard(
                    index: i,
                    number: i + 1,
                    text: q.text,
                    chip: controller.chip(q),
                    warn: q.photoRule == 'if_fail' || q.photoRule == 'if_no',
                    editable: controller.editable,
                    onTap: () {
                      if (!controller.editable) return;
                      controller.startEdit(q);
                      _question(edit: true);
                    },
                  ),
                );
              },
            );
          }),
        ),
      ),
      bottomNavigationBar: Obx(() {
        final t = controller.template.value;
        if (t == null) return const SizedBox.shrink();
        return KnScreenFooter(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IntrinsicWidth(
                child: controller.editable
                    ? KnCustomButton(
                        key: const ValueKey('checklist-save'),
                        text: LangKeys.cbSave.tr,
                        icon: LucideIcons.check,
                        loading: controller.busy.value,
                        onTap: controller.onSave,
                      )
                    : KnCustomButton(
                        key: const ValueKey('checklist-copy'),
                        text: LangKeys.cbCopy.tr,
                        icon: LucideIcons.plus,
                        loading: controller.busy.value,
                        onTap: controller.onCopy,
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.label, required this.good, required this.done});

  final IconData icon;
  final String label;
  final bool good;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final fg = good ? kn.statusSuccess : kn.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 10),
      decoration: BoxDecoration(
        color: good ? kn.statusSuccessBg : kn.actionSecondary,
        borderRadius: BorderRadius.circular(KnSize.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: KnSize.space8),
          Expanded(child: CustomBaseTextWidget(label, style: context.knText.labelSm, color: fg)),
          if (done) Icon(LucideIcons.check, size: 18, color: fg),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.number,
    required this.text,
    required this.chip,
    required this.warn,
    required this.editable,
    required this.onTap,
  });

  final int index;
  final int number;
  final String text;
  final String chip;
  final bool warn;
  final bool editable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final t = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: text,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(KnSize.space8, KnSize.space12, KnSize.space12, KnSize.space12),
        decoration: BoxDecoration(color: kn.bgSurface, borderRadius: radius, border: Border.all(color: kn.borderDefault)),
        child: Row(
          children: [
            if (editable)
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.all(KnSize.space8),
                  child: Icon(LucideIcons.menu, size: 20, color: kn.textPrimary),
                ),
              )
            else
              const SizedBox(width: KnSize.space8),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: kn.actionSecondary, shape: BoxShape.circle),
              child: CustomBaseTextWidget('$number', style: t.labelSm),
            ),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(text, style: t.label, maxLines: 3),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: warn ? kn.statusWarningBg : kn.actionSecondary,
                      borderRadius: BorderRadius.circular(KnSize.radiusFull),
                    ),
                    child: CustomBaseTextWidget(chip, style: t.labelSm, color: warn ? kn.statusWarning : kn.textPrimary),
                  ),
                ],
              ),
            ),
            if (editable) Icon(LucideIcons.chevronRight, size: 20, color: kn.textSecondary),
          ],
        ),
      ),
    );
  }
}
