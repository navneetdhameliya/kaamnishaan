import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/part_field.dart';
import 'report_editor_controller.dart';

/// M32 Report editor (Figma 31:1509; empty part 74:2390).
class ReportEditorScreen extends GetView<ReportEditorController> {
  const ReportEditorScreen({super.key});

  Future<bool> _ask({required String title, required String body, required String yes, IconData? icon}) async =>
      await showKnBottomSheet<bool>(
        title: title,
        child: Builder(
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomBaseTextWidget(body, style: context.knText.body, color: context.kn.textSecondary),
              const SizedBox(height: KnSize.space16),
              KnCustomButton(
                key: const ValueKey('sheet-yes'),
                text: yes,
                icon: icon,
                onTap: () => Get.back<bool>(result: true),
              ),
              KnCustomButton(
                text: LangKeys.commonCancel.tr,
                variant: KnButtonVariant.ghost,
                onTap: () => Get.back<bool>(result: false),
              ),
            ],
          ),
        ),
      ) ??
      false;

  Future<void> _rewrite(ReportPart p) async {
    final yes = await _ask(
      title: LangKeys.editorAiTitle.trParams({'part': p.title}),
      body: LangKeys.editorAiBody.tr,
      yes: LangKeys.editorAiYes.tr,
      icon: LucideIcons.sparkles,
    );
    if (yes) await controller.rewrite(p);
  }

  Future<void> _leave() async {
    if (controller.hasChanges) {
      final yes = await _ask(
        title: LangKeys.editorUnsavedTitle.tr,
        body: LangKeys.editorUnsavedBody.tr,
        yes: LangKeys.editorLeave.tr,
      );
      if (!yes) return;
    }
    Get.back<bool>(result: false);
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: kn.bgCanvas,
        bottomNavigationBar: KnScreenFooter(
          children: [
            Obx(
              () => KnCustomButton(
                key: const ValueKey('editor-save'),
                text: LangKeys.editorSave.tr,
                icon: LucideIcons.check,
                enabled: controller.canSave,
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
            child: Obx(
              () => ListView(
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
                children: [
                  Row(
                    children: [
                      KnBackButton(onTap: _leave),
                      const SizedBox(width: KnSize.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomBaseTextWidget(LangKeys.editorTitle.tr, style: text.h3),
                            CustomBaseTextWidget(
                              LangKeys.editorSubtitle.trParams({'customer': controller.args.customer}),
                              style: text.caption,
                              color: kn.textSecondary,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space16),
                  if (!controller.loaded) ...const [
                    CommonShimmer(height: 110, radius: KnSize.radiusLg),
                    SizedBox(height: KnSize.space16),
                    CommonShimmer(height: 140, radius: KnSize.radiusLg),
                  ] else ...[
                    for (final p in controller.parts) ...[
                      PartField(
                        part: p,
                        showAi: controller.canRewrite,
                        aiWritten: controller.sourceOf(p) != 'technician',
                        emptyText: controller.emptyText(p),
                        onMic: () => controller.onMicTap(p),
                        onAi: () => _rewrite(p),
                        onHear: () => controller.onHearTap(p),
                      ),
                      const SizedBox(height: KnSize.space16),
                    ],
                    Container(
                      padding: const EdgeInsets.all(KnSize.space12),
                      decoration: BoxDecoration(
                        color: kn.actionSecondary,
                        borderRadius: BorderRadius.circular(KnSize.radiusLg),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.lock, size: 16, color: kn.textSecondary),
                          const SizedBox(width: KnSize.space8),
                          Expanded(
                            child: CustomBaseTextWidget(
                              LangKeys.editorLockedNote.tr,
                              style: text.caption,
                              color: kn.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
