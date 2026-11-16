import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../../infrastructure/shared/text_utils.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M13 "Team right now" card: photo with a status dot, first name, and on a job / free / invite sent.
class TeamMemberCard extends StatelessWidget {
  const TeamMemberCard({super.key, required this.member, required this.onTap});

  final TeamNowModel member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final (label, color) = switch (member.status) {
      'on_job' => (LangKeys.dashOnJob.tr, kn.statusSuccess),
      'invited' => (LangKeys.dashInviteSent.tr, kn.textSecondary),
      _ => (LangKeys.dashFree.tr, kn.textSecondary),
    };
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: '${member.name}, $label',
      child: Ink(
        width: 104,
        height: 100,
        padding: const EdgeInsets.all(KnSize.space8),
        decoration: BoxDecoration(color: kn.bgSurface, borderRadius: radius, border: Border.all(color: kn.borderDefault)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  KnInitialsAvatar(
                    initials: TextUtils.initials(member.name),
                    url: member.avatarUrl,
                    size: 40,
                    borderWidth: 0,
                  ),
                  Positioned(
                    left: 29,
                    top: 29,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: member.status == 'on_job' ? kn.statusSuccess : kn.textSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: kn.bgSurface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KnSize.space2),
            CustomBaseTextWidget(TextUtils.firstName(member.name), style: text.labelSm, maxLines: 1),
            CustomBaseTextWidget(label, style: text.caption, color: color, maxLines: 1),
          ],
        ),
      ),
    );
  }
}
