import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_text_box.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'checklist_library_controller.dart';

/// The company's checklists, opened from Me (owners and managers); each opens the builder (M26).
class ChecklistLibraryScreen extends GetView<ChecklistLibraryController> {
  const ChecklistLibraryScreen({super.key});

  void _new() {
    controller.startNew();
    showKnBottomSheet<void>(
      title: LangKeys.cbNew.tr,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(Get.context!).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomBaseTextWidget(LangKeys.cbName.tr, style: Get.context!.knText.label),
            const SizedBox(height: KnSize.space8),
            KnTextBox(
              fieldKey: const ValueKey('checklist-name'),
              controller: controller.name,
              hint: LangKeys.cbNameHint.tr,
              minLines: 1,
              maxLines: 2,
              maxLength: 120,
            ),
            const SizedBox(height: KnSize.space16),
            Obx(
              () => KnCustomButton(
                key: const ValueKey('checklist-create'),
                text: LangKeys.cbCreate.tr,
                loading: controller.creating.value,
                enabled: controller.nameDraft.value.trim().isNotEmpty,
                onTap: controller.onCreate,
              ),
            ),
          ],
        ),
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
          child: RefreshIndicator(
            onRefresh: controller.load,
            child: Obx(
              () => ListView(
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
                children: [
                  KnTitleBar(title: LangKeys.cbTitle.tr),
                  const SizedBox(height: KnSize.space16),
                  if (controller.loading.value && controller.items.isEmpty)
                    for (var i = 0; i < 4; i++) ...[
                      const CommonShimmer(height: 76, radius: KnSize.radiusLg),
                      const SizedBox(height: KnSize.space12),
                    ],
                  for (final t in controller.items) ...[
                    CustomInkWell(
                      key: ValueKey('template-${t.id}'),
                      onTap: () => controller.onOpen(t.id),
                      borderRadius: BorderRadius.circular(KnSize.radiusLg),
                      semanticLabel: t.name,
                      child: Ink(
                        padding: const EdgeInsets.all(KnSize.space16),
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
                              decoration: BoxDecoration(color: kn.actionSecondary, shape: BoxShape.circle),
                              child: Icon(LucideIcons.listChecks, size: 20, color: kn.textPrimary),
                            ),
                            const SizedBox(width: KnSize.space12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CustomBaseTextWidget(t.name, style: text.label, maxLines: 2),
                                  CustomBaseTextWidget(controller.meta(t), style: text.caption, color: kn.textSecondary),
                                  if (controller.badge(t) != null) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: t.scope == 'company' ? kn.statusWarningBg : kn.bgSubtle,
                                        borderRadius: BorderRadius.circular(KnSize.radiusFull),
                                      ),
                                      child: CustomBaseTextWidget(
                                        controller.badge(t)!,
                                        style: text.labelSm,
                                        color: t.scope == 'company' ? kn.statusWarning : kn.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Icon(LucideIcons.chevronRight, size: 20, color: kn.textSecondary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: KnSize.space12),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: KnScreenFooter(
        children: [
          KnCustomButton(key: const ValueKey('checklist-new'), text: LangKeys.cbNew.tr, icon: LucideIcons.plus, onTap: _new),
        ],
      ),
    );
  }
}
