import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_bottom_sheet.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../home_shell_controller.dart';

/// The camera button with no job going on (D-140). Technicians: today's next jobs (their page has
/// Start) and "Quick job" for work that wasn't planned. Owners and managers: New job and the jobs list.
Future<void> showCaptureSheet(HomeShellController c) => showKnBottomSheet<void>(
      title: LangKeys.capTitle.tr,
      child: Builder(
        builder: (context) {
          final kn = context.kn;
          final jobs = c.isManager ? const [] : c.captureJobs;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CustomBaseTextWidget(
                c.isManager ? LangKeys.capSubManager.tr : LangKeys.capSub.tr,
                style: context.knText.body,
                color: kn.textSecondary,
              ),
              const SizedBox(height: KnSize.space12),
              if (c.isManager) ...[
                _Row(
                  key: const ValueKey('cap-new-job'),
                  icon: LucideIcons.plus,
                  title: LangKeys.capNewJob.tr,
                  sub: LangKeys.capNewJobSub.tr,
                  onTap: c.onNewJobTap,
                ),
                _Row(
                  key: const ValueKey('cap-all-jobs'),
                  icon: LucideIcons.briefcase,
                  title: LangKeys.capAllJobs.tr,
                  sub: LangKeys.capAllJobsSub.tr,
                  onTap: c.onAllJobsTap,
                ),
              ] else ...[
                for (final j in jobs)
                  _Row(
                    key: ValueKey('cap-job-${j.id}'),
                    icon: LucideIcons.mapPin,
                    title: j.customer.name,
                    sub: c.jobLine(j),
                    onTap: () => c.onCaptureJobTap(j),
                  ),
                _Row(
                  key: const ValueKey('cap-quick-job'),
                  icon: LucideIcons.zap,
                  title: LangKeys.capQuickJob.tr,
                  sub: LangKeys.capQuickJobSub.tr,
                  onTap: c.onQuickJobTap,
                  strong: true,
                ),
              ],
            ],
          );
        },
      ),
    );

class _Row extends StatelessWidget {
  const _Row({super.key, required this.icon, required this.title, required this.sub, required this.onTap, this.strong = false});

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Padding(
      padding: const EdgeInsets.only(bottom: KnSize.space8),
      child: CustomInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        child: Ink(
          padding: const EdgeInsets.all(KnSize.space12),
          decoration: BoxDecoration(
            color: strong ? kn.actionSecondary : kn.bgSurface,
            borderRadius: BorderRadius.circular(KnSize.radiusLg),
            border: Border.all(color: kn.borderDefault),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: kn.bgCanvas, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: kn.textPrimary),
              ),
              const SizedBox(width: KnSize.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomBaseTextWidget(title, style: text.label, maxLines: 1),
                    const SizedBox(height: 2),
                    CustomBaseTextWidget(sub, style: text.caption, color: kn.textSecondary, maxLines: 2),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 18, color: kn.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
