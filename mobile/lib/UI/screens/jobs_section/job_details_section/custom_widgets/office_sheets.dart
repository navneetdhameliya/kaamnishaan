import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_bottom_sheet.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_text_box.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../../job_list_section/custom_widgets/job_list_parts.dart';
import '../job_details_controller.dart';

/// The "⋯" on M15 for owners and managers: change the technician, cancel the job, delete it (D-139).
Future<void> showJobOfficeMenu(JobDetailsController c) => showKnBottomSheet<void>(
      title: LangKeys.jobMenu.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.canAssign)
            _MenuRow(
              key: const ValueKey('job-menu-assign'),
              icon: LucideIcons.userCheck,
              label: c.assignLabel,
              onTap: () {
                Get.back<void>();
                c.onAssignTap();
              },
            ),
          if (c.canCancel)
            _MenuRow(
              key: const ValueKey('job-menu-cancel'),
              icon: LucideIcons.ban,
              label: LangKeys.jobCancel.tr,
              danger: true,
              onTap: () {
                Get.back<void>();
                c.startCancel();
                showCancelJobSheet(c);
              },
            ),
          if (c.canDelete)
            _MenuRow(
              key: const ValueKey('job-menu-delete'),
              icon: LucideIcons.trash2,
              label: LangKeys.jobDelete.tr,
              danger: true,
              onTap: () {
                Get.back<void>();
                c.onDeleteTap();
              },
            ),
        ],
      ),
    );

class _MenuRow extends StatelessWidget {
  const _MenuRow({super.key, required this.icon, required this.label, required this.onTap, this.danger = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final colour = danger ? kn.statusDanger : kn.textPrimary;
    return CustomInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KnSize.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: KnSize.space4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: colour),
            const SizedBox(width: KnSize.space12),
            Expanded(child: CustomBaseTextWidget(label, style: context.knText.label, color: colour)),
          ],
        ),
      ),
    );
  }
}

/// "Cancel this job?": a quick reason or typed words (they go on the job's timeline), then Cancel job.
Future<void> showCancelJobSheet(JobDetailsController c) => showKnBottomSheet<void>(
      title: LangKeys.jobCancelTitle.tr,
      child: Builder(
        builder: (context) => Obx(() {
        final kn = context.kn;
        final text = context.knText;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomBaseTextWidget(LangKeys.jobCancelBody.tr, style: text.body, color: kn.textSecondary),
            const SizedBox(height: KnSize.space12),
            Wrap(
              spacing: KnSize.space8,
              runSpacing: KnSize.space8,
              children: [
                for (final (i, r) in c.cancelReasons.indexed)
                  JobFilterChip(
                    key: ValueKey('cancel-why-$i'),
                    label: r,
                    selected: c.cancelDraft.value == r,
                    onTap: () => c.onCancelReasonPick(r),
                  ),
              ],
            ),
            const SizedBox(height: KnSize.space12),
            KnTextBox(
              fieldKey: const ValueKey('cancel-why'),
              controller: c.cancelReason,
              hint: LangKeys.jobCancelHint.tr,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
            ),
            const SizedBox(height: KnSize.space16),
            KnCustomButton(
              key: const ValueKey('cancel-job'),
              text: LangKeys.jobCancel.tr,
              icon: LucideIcons.ban,
              variant: KnButtonVariant.danger,
              enabled: c.canSendCancel,
              loading: c.busy.value == 'cancel',
              onTap: () async {
                if (await c.onCancelJob()) Get.back<void>();
              },
            ),
          ],
        );
      }),
      ),
    );
