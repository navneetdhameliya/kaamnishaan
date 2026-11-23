import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_initials_avatar.dart';
import '../../../common_widgets/kn_page_scaffold.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'team_member_controller.dart';

/// A team member's own page (no Figma frame: M40's rows and M18's cards).
class TeamMemberScreen extends GetView<TeamMemberController> {
  const TeamMemberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.onBackTap();
      },
      child: KnPageScaffold(
        onBack: controller.onBackTap,
        body: Obx(() {
          final c = controller;
          final m = c.m;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: KnSize.space16),
              Center(child: KnInitialsAvatar(initials: c.initials, url: m.avatarUrl, size: 88, borderWidth: 0)),
              const SizedBox(height: KnSize.space12),
              CustomBaseTextWidget(
                c.isMe ? LangKeys.teamYou.trParams({'name': m.name}) : m.name,
                key: const ValueKey('member-name'),
                style: text.h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KnSize.space8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: KnSize.space8,
                runSpacing: KnSize.space8,
                children: [
                  _Chip(label: c.roleLabel, color: kn.actionSecondary, fg: kn.textPrimary),
                  if (c.state != null)
                    _Chip(
                      label: c.state!,
                      color: c.invited ? kn.statusWarningBg : kn.statusSuccessBg,
                      fg: c.invited ? kn.statusWarning : kn.statusSuccess,
                    ),
                ],
              ),
              if (c.since != null) ...[
                const SizedBox(height: KnSize.space8),
                CustomBaseTextWidget(c.since!, style: text.caption, color: kn.textSecondary, textAlign: TextAlign.center),
              ],
              if ((m.phone ?? '').isNotEmpty) ...[
                const SizedBox(height: KnSize.space24),
                _Card(
                  child: Row(
                    children: [
                      Icon(LucideIcons.phone, size: 20, color: kn.textSecondary),
                      const SizedBox(width: KnSize.space12),
                      Expanded(child: CustomBaseTextWidget(m.phone!, style: text.body)),
                      if (c.canCall)
                        CustomInkWell(
                          key: const ValueKey('member-call'),
                          onTap: c.onCallTap,
                          borderRadius: BorderRadius.circular(KnSize.radiusFull),
                          semanticLabel: LangKeys.tmCall.tr,
                          child: Ink(
                            padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: 10),
                            decoration: BoxDecoration(
                              color: kn.actionSecondary,
                              borderRadius: BorderRadius.circular(KnSize.radiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.phoneCall, size: 16, color: kn.textPrimary),
                                const SizedBox(width: KnSize.space8),
                                CustomBaseTextWidget(LangKeys.tmCall.tr, style: text.labelSm),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (c.showJobs) ...[
                const SizedBox(height: KnSize.space16),
                if (c.loading.value)
                  const CommonShimmer(height: 92, radius: KnSize.radiusLg)
                else
                  _Card(
                    child: Row(
                      children: [
                        _Stat(key: const ValueKey('member-waiting'), n: c.waitingJobs, label: LangKeys.tmWaiting.tr),
                        _Stat(key: const ValueKey('member-active'), n: c.activeJobs, label: LangKeys.tmActive.tr),
                        _Stat(key: const ValueKey('member-done'), n: c.doneJobs, label: LangKeys.tmDone.tr),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: KnSize.space24),
              if (c.canHandleInvite) ...[
                KnCustomButton(
                  key: const ValueKey('member-resend'),
                  text: LangKeys.teamResend.tr,
                  icon: LucideIcons.send,
                  variant: KnButtonVariant.secondary,
                  loading: c.busy.value == 'resend',
                  onTap: c.onResendTap,
                ),
                const SizedBox(height: KnSize.space12),
                KnCustomButton(
                  key: const ValueKey('member-cancel-invite'),
                  text: LangKeys.tmCancelInvite.tr,
                  icon: LucideIcons.x,
                  variant: KnButtonVariant.ghost,
                  loading: c.busy.value == 'cancel',
                  onTap: c.onCancelInviteTap,
                ),
              ],
              if (c.canChangeRole) ...[
                KnCustomButton(
                  key: const ValueKey('member-role'),
                  text: c.roleAction,
                  icon: c.technician ? LucideIcons.shieldCheck : LucideIcons.wrench,
                  variant: KnButtonVariant.secondary,
                  loading: c.busy.value == 'role',
                  onTap: c.onRoleTap,
                ),
                const SizedBox(height: KnSize.space12),
              ],
              if (c.canRemove)
                KnCustomButton(
                  key: const ValueKey('member-remove'),
                  text: LangKeys.tmRemove.tr,
                  icon: LucideIcons.userMinus,
                  variant: KnButtonVariant.danger,
                  loading: c.busy.value == 'remove',
                  onTap: c.onRemoveTap,
                ),
              if (!c.isMe && !c.canRemove && !c.canHandleInvite && m.role != 'owner') ...[
                CustomBaseTextWidget(
                  LangKeys.tmOwnerOnly.tr,
                  style: text.caption,
                  color: kn.textSecondary,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: KnSize.space24),
            ],
          );
        }),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, required this.fg});

  final String label;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
        child: CustomBaseTextWidget(label, style: context.knText.labelSm, color: fg),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
        boxShadow: KnShadow.sm,
      ),
      child: child,
    );
  }
}

/// "2 / Not started" — one of the three job counts.
class _Stat extends StatelessWidget {
  const _Stat({super.key, required this.n, required this.label});

  final int n;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            CustomBaseTextWidget('$n', style: context.knText.h2),
            const SizedBox(height: 2),
            CustomBaseTextWidget(
              label,
              style: context.knText.caption,
              color: context.kn.textSecondary,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
