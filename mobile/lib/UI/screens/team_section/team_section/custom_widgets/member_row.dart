import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_dashed_border.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../team_controller.dart';

/// A photo with a small dot: green when busy or online, brown when driving, grey otherwise.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.url, required this.dot, this.faded = false});

  final String initials;
  final String? url;
  final Color dot;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          Opacity(opacity: faded ? 0.6 : 1, child: KnInitialsAvatar(initials: initials, url: url, size: 44, borderWidth: 0)),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot,
                border: Border.all(color: context.kn.bgSurface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One person in the team card: photo, name, role and jobs, what they are doing, and a chevron.
class MemberRow extends StatelessWidget {
  const MemberRow({
    super.key,
    required this.name,
    required this.initials,
    required this.line,
    required this.tone,
    required this.onTap,
    this.avatarUrl,
    this.state,
    this.divider = true,
  });

  final String name;
  final String initials;
  final String? avatarUrl;
  final String line;
  final String? state;
  final MemberTone tone;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final colour = switch (tone) {
      MemberTone.good => kn.statusSuccess,
      MemberTone.info => kn.statusInfo,
      MemberTone.quiet => kn.textSecondary,
    };
    final said = state;
    return CustomInkWell(
      onTap: onTap,
      semanticLabel: name,
      child: Container(
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(
          border: divider ? Border(bottom: BorderSide(color: kn.borderDefault)) : null,
        ),
        child: Row(
          children: [
            _Avatar(initials: initials, url: avatarUrl, dot: said == null ? kn.statusOffline : colour),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(name, style: text.label, maxLines: 1),
                  const SizedBox(height: 2),
                  CustomBaseTextWidget(line, style: text.caption, color: kn.textSecondary, maxLines: 1),
                ],
              ),
            ),
            if (said != null) ...[
              const SizedBox(width: KnSize.space8),
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: colour)),
              const SizedBox(width: 4),
              CustomBaseTextWidget(said, style: text.captionStrong, color: colour),
            ],
            const SizedBox(width: KnSize.space8),
            Icon(LucideIcons.chevronRight, size: 20, color: kn.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Someone who has not joined yet: dashed orange card with "Resend".
class WaitingCard extends StatelessWidget {
  const WaitingCard({
    super.key,
    required this.name,
    required this.initials,
    required this.line,
    required this.onResend,
    this.avatarUrl,
    this.sending = false,
  });

  final String name;
  final String initials;
  final String? avatarUrl;
  final String line;
  final bool sending;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return KnDashedBorder(
      color: kn.statusWarning,
      radius: KnSize.radiusLg,
      child: Container(
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(color: kn.bgSurface, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
        child: Row(
          children: [
            _Avatar(initials: initials, url: avatarUrl, dot: kn.statusOffline, faded: true),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(name, style: text.label, maxLines: 1),
                  const SizedBox(height: 2),
                  CustomBaseTextWidget(line, style: text.caption, color: kn.textSecondary, maxLines: 2),
                ],
              ),
            ),
            const SizedBox(width: KnSize.space8),
            KnCustomButton(
              text: LangKeys.teamResend.tr,
              icon: LucideIcons.refreshCw,
              variant: KnButtonVariant.secondary,
              small: true,
              loading: sending,
              onTap: onResend,
            ),
          ],
        ),
      ),
    );
  }
}
