import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M13 new company "Get started": create company (done), invite your team, create the first job.
class GetStartedCard extends StatelessWidget {
  const GetStartedCard({
    super.key,
    required this.company,
    required this.teamInvited,
    required this.jobCreated,
    required this.onInvite,
    required this.onCreateJob,
  });

  final String company;
  final bool teamInvited;
  final bool jobCreated;
  final VoidCallback onInvite;
  final VoidCallback onCreateJob;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final done = 1 + (teamInvited ? 1 : 0) + (jobCreated ? 1 : 0);
    return Container(
      key: const ValueKey('get-started'),
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
        boxShadow: KnShadow.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: CustomBaseTextWidget(LangKeys.dashGetStarted.tr, style: text.h3)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
                decoration: BoxDecoration(color: kn.statusSuccessBg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                child: CustomBaseTextWidget(
                  LangKeys.dashStepsDone.trParams({'done': '$done', 'total': '3'}),
                  style: text.labelSm,
                  color: kn.statusSuccess,
                ),
              ),
            ],
          ),
          const SizedBox(height: KnSize.space12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: done / 3,
              minHeight: 6,
              backgroundColor: kn.bgSubtle,
              color: kn.statusSuccess,
            ),
          ),
          const SizedBox(height: KnSize.space12),
          _step(
            context,
            icon: LucideIcons.building,
            title: LangKeys.dashStepCompany.tr,
            body: LangKeys.dashStepCompanyDone.trParams({'company': company}),
            done: true,
          ),
          Divider(height: 1, color: kn.borderDefault),
          _step(
            context,
            icon: LucideIcons.users,
            title: LangKeys.dashStepTeam.tr,
            body: LangKeys.dashStepTeamBody.tr,
            done: teamInvited,
            action: KnCustomButton(
              key: const ValueKey('invite-team'),
              text: LangKeys.dashInvite.tr,
              small: true,
              onTap: onInvite,
            ),
          ),
          Divider(height: 1, color: kn.borderDefault),
          _step(
            context,
            icon: LucideIcons.briefcase,
            title: LangKeys.dashStepJob.tr,
            body: LangKeys.dashStepJobBody.tr,
            done: jobCreated,
            action: KnCustomButton(
              key: const ValueKey('create-job'),
              text: LangKeys.dashCreate.tr,
              small: true,
              variant: KnButtonVariant.secondary,
              onTap: onCreateJob,
            ),
          ),
        ],
      ),
    );
  }

  Widget _step(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required bool done,
    Widget? action,
  }) {
    final kn = context.kn;
    final text = context.knText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: KnSize.space12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: done ? kn.statusSuccess : kn.bgSubtle, shape: BoxShape.circle),
            child: Icon(done ? LucideIcons.check : icon, size: 18, color: done ? KnPrimitive.cream50 : kn.textPrimary),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(
                  title,
                  style: done
                      ? text.label.copyWith(decoration: TextDecoration.lineThrough, decorationColor: kn.textSecondary)
                      : text.label,
                  color: done ? kn.textSecondary : kn.textPrimary,
                ),
                const SizedBox(height: KnSize.space2),
                CustomBaseTextWidget(body, style: text.caption, color: kn.textSecondary),
              ],
            ),
          ),
          if (!done && action != null) ...[const SizedBox(width: KnSize.space12), action],
        ],
      ),
    );
  }
}
