import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_title_bar.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'assign_technician_controller.dart';
import 'custom_widgets/technician_card.dart';

/// M17 Assign technician (Figma 45:1161; no technicians 45:1220).
class AssignTechnicianScreen extends GetView<AssignTechnicianController> {
  const AssignTechnicianScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Obx(() {
      final empty = controller.empty;
      return Scaffold(
        backgroundColor: kn.bgCanvas,
        bottomNavigationBar: KnScreenFooter(
          children: empty
              ? [
                  KnCustomButton(
                    key: const ValueKey('assign-invite'),
                    text: LangKeys.assignInvite.tr,
                    icon: LucideIcons.plus,
                    onTap: controller.onInviteTap,
                  ),
                  if (controller.canSaveWithout)
                    KnCustomButton(
                      key: const ValueKey('assign-save-without'),
                      text: LangKeys.assignSaveWithout.tr,
                      variant: KnButtonVariant.ghost,
                      onTap: controller.onSaveWithoutTap,
                    ),
                ]
              : [
                  KnCustomButton(
                    key: const ValueKey('assign-button'),
                    text: controller.buttonText,
                    enabled: controller.chosen != null,
                    loading: controller.saving.value,
                    onTap: controller.onAssignTap,
                  ),
                ],
        ),
        body: SafeArea(
          bottom: false,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
              children: [
                KnTitleBar(title: LangKeys.assignTitle.tr, subtitle: LangKeys.assignSubtitle.tr),
                const SizedBox(height: KnSize.space16),
                _JobSummary(customer: controller.args.customer, summary: controller.summary),
                const SizedBox(height: KnSize.space16),
                if (controller.loading.value)
                  for (var i = 0; i < 3; i++) ...const [
                    CommonShimmer(height: 84, radius: KnSize.radiusLg),
                    SizedBox(height: KnSize.space12),
                  ]
                else if (empty)
                  const _NoTechnicians()
                else ...[
                  CustomBaseTextWidget(controller.heading, style: text.label, color: kn.textSecondary),
                  const SizedBox(height: KnSize.space12),
                  for (final t in controller.people) ...[
                    TechnicianCard(
                      key: ValueKey('tech-${t.id}'),
                      name: t.name,
                      initials: TextUtils.initials(t.name),
                      avatarUrl: t.avatarUrl,
                      line: controller.line(t),
                      loadText: controller.loadText(t),
                      share: controller.share(t),
                      tone: controller.tone(t),
                      invited: controller.invited(t),
                      selected: controller.picked.value == t.id,
                      onTap: () => controller.onPersonTap(t),
                    ),
                    const SizedBox(height: KnSize.space12),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// The job being given: customer, then work and when.
class _JobSummary extends StatelessWidget {
  const _JobSummary({required this.customer, required this.summary});

  final String customer;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSubtle,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: kn.bgSurface, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
            child: Icon(LucideIcons.briefcase, size: 22, color: kn.textSecondary),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(customer, style: text.label, maxLines: 1),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  CustomBaseTextWidget(summary, style: text.caption, color: kn.textSecondary, maxLines: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoTechnicians extends StatelessWidget {
  const _NoTechnicians();

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Padding(
      padding: const EdgeInsets.only(top: 56),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: kn.bgSubtle),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kn.bgSurface),
              child: Icon(LucideIcons.users, size: 32, color: kn.textSecondary),
            ),
          ),
          const SizedBox(height: KnSize.space24),
          CustomBaseTextWidget(LangKeys.assignEmptyTitle.tr, style: text.h2, textAlign: TextAlign.center),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(
            LangKeys.assignEmptyBody.tr,
            style: text.body,
            color: kn.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
