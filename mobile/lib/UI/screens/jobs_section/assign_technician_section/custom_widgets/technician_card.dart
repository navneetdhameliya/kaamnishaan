import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../assign_technician_controller.dart';

/// One person on M17: photo, name, jobs that day, a bar of how full the day is, and a round tick.
/// People who have not joined yet are greyed out with "Can assign after joining".
class TechnicianCard extends StatelessWidget {
  const TechnicianCard({
    super.key,
    required this.name,
    required this.initials,
    required this.line,
    required this.selected,
    required this.invited,
    required this.onTap,
    this.avatarUrl,
    this.loadText,
    this.share = 0,
    this.tone = LoadTone.light,
  });

  final String name;
  final String initials;
  final String? avatarUrl;
  final String line;
  final String? loadText;
  final double share;
  final LoadTone tone;
  final bool selected;
  final bool invited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    final bar = switch (tone) {
      LoadTone.light => kn.statusSuccess,
      LoadTone.busy => kn.statusWarning,
      LoadTone.full => kn.statusDanger,
    };
    return Opacity(
      opacity: invited ? 0.55 : 1,
      child: CustomInkWell(
        onTap: onTap,
        borderRadius: radius,
        semanticLabel: name,
        child: Ink(
          padding: const EdgeInsets.all(KnSize.space12),
          decoration: BoxDecoration(
            color: kn.bgSurface,
            borderRadius: radius,
            border: Border.all(color: selected ? kn.actionPrimary : kn.borderDefault, width: selected ? 2 : 1),
            boxShadow: selected ? KnShadow.md : KnShadow.sm,
          ),
          child: Row(
            children: [
              KnInitialsAvatar(initials: initials, url: avatarUrl, size: 48, borderWidth: 0),
              const SizedBox(width: KnSize.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomBaseTextWidget(name, style: text.label, maxLines: 1),
                    const SizedBox(height: 4),
                    CustomBaseTextWidget(line, style: text.caption, color: kn.textSecondary, maxLines: 1),
                    const SizedBox(height: 4),
                    if (invited)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: kn.statusOfflineBg, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.clock, size: 14, color: kn.statusOffline),
                            const SizedBox(width: 6),
                            Flexible(
                              child: CustomBaseTextWidget(
                                LangKeys.assignAfterJoining.tr,
                                style: text.labelSm,
                                color: kn.statusOffline,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              width: 120,
                              height: 6,
                              child: LinearProgressIndicator(
                                value: share,
                                backgroundColor: kn.bgSubtle,
                                valueColor: AlwaysStoppedAnimation(bar),
                              ),
                            ),
                          ),
                          const SizedBox(width: KnSize.space8),
                          Flexible(
                            child: CustomBaseTextWidget(
                              loadText ?? '',
                              style: text.caption,
                              color: tone == LoadTone.full ? kn.statusDanger : kn.textSecondary,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(width: KnSize.space12),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? kn.actionPrimary : kn.bgSurface,
                  border: selected ? null : Border.all(color: kn.borderStrong, width: 2),
                ),
                child: selected ? Icon(LucideIcons.check, size: 16, color: kn.textOnAction) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
