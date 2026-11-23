import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_bottom_sheet.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../job_list_controller.dart';
import 'job_list_parts.dart';

/// M14 Filters: the job's state and, for owners and managers, the technician (D-139). "Show jobs" applies;
/// "Clear" empties the sheet. The day chips (Today, Tomorrow, Unassigned) stay on the list itself.
Future<void> showJobFiltersSheet(JobListController c) async {
  await c.startFilters();
  await showKnBottomSheet<void>(
    title: LangKeys.jobsFilters.tr,
    child: Builder(
      builder: (context) => Obx(() {
        final kn = context.kn;
        final text = context.knText;
        Widget heading(String s) => Padding(
              padding: const EdgeInsets.only(bottom: KnSize.space8),
              child: CustomBaseTextWidget(s, style: text.label, color: kn.textSecondary),
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading(LangKeys.jfState.tr),
            Wrap(
              spacing: KnSize.space8,
              runSpacing: KnSize.space8,
              children: [
                for (final s in JobState.values)
                  JobFilterChip(
                    key: ValueKey('jf-${s.name}'),
                    label: c.stateLabel(s),
                    selected: c.draftState.value == s,
                    onTap: () => c.onDraftState(s),
                  ),
              ],
            ),
            if (c.isManager && c.technicians.isNotEmpty) ...[
              const SizedBox(height: KnSize.space16),
              heading(LangKeys.jfTechnician.tr),
              Wrap(
                spacing: KnSize.space8,
                runSpacing: KnSize.space8,
                children: [
                  for (final t in c.technicians)
                    JobFilterChip(
                      key: ValueKey('jf-tech-${t.id}'),
                      label: t.name,
                      selected: c.draftTechnician.value == t.id,
                      onTap: () => c.onDraftTechnician(t.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: KnSize.space24),
            Row(
              children: [
                Expanded(
                  child: KnCustomButton(
                    key: const ValueKey('jf-clear'),
                    text: LangKeys.jfClear.tr,
                    variant: KnButtonVariant.secondary,
                    onTap: c.onResetDraft,
                  ),
                ),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  child: KnCustomButton(
                    key: const ValueKey('jf-apply'),
                    text: LangKeys.jfShow.tr,
                    icon: LucideIcons.check,
                    onTap: () {
                      c.onApplyFilters();
                      Get.back<void>();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      }),
    ),
  );
}
