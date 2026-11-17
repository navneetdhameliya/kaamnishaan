import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// "2 things are missing. Please fill them in." across the top (Figma 44:1144).
class MissingBanner extends StatelessWidget {
  const MissingBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      key: const ValueKey('newjob-missing'),
      color: kn.statusDangerBg,
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: KnSize.space12),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, size: 20, color: kn.statusDanger),
          const SizedBox(width: KnSize.space8),
          Expanded(child: CustomBaseTextWidget(text, style: context.knText.labelSm, color: kn.statusDanger)),
        ],
      ),
    );
  }
}

/// The technician row on New job: "Not assigned yet · Assign" or the picked person with "Change".
class AssignRow extends StatelessWidget {
  const AssignRow({
    super.key,
    required this.name,
    required this.line,
    required this.initials,
    required this.onTap,
    this.avatarUrl,
  });

  /// Null: nobody picked yet.
  final String? name;
  final String line;
  final String initials;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final who = name;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      key: const ValueKey('newjob-assign'),
      onTap: onTap,
      borderRadius: radius,
      child: Ink(
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: kn.borderDefault),
          boxShadow: KnShadow.sm,
        ),
        child: Row(
          children: [
            if (who == null)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kn.bgSubtle),
                child: Icon(LucideIcons.user, size: 20, color: kn.textSecondary),
              )
            else
              KnInitialsAvatar(initials: initials, url: avatarUrl, size: 40, borderWidth: 0),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(who ?? LangKeys.newjobNotAssigned.tr, style: text.label, maxLines: 1),
                  const SizedBox(height: 2),
                  CustomBaseTextWidget(line, style: text.caption, color: kn.textSecondary, maxLines: 1),
                ],
              ),
            ),
            const SizedBox(width: KnSize.space8),
            CustomBaseTextWidget(
              who == null ? LangKeys.newjobAssign.tr : LangKeys.newjobChange.tr,
              style: text.label,
              color: kn.textLink,
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.chevronRight, size: 18, color: kn.textLink),
          ],
        ),
      ),
    );
  }
}

/// One row in a pick list sheet (a customer, a checklist).
class PickRow extends StatelessWidget {
  const PickRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.selected = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final sub = subtitle;
    final radius = BorderRadius.circular(KnSize.radiusMd);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 10),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: selected ? kn.actionPrimary : kn.borderDefault, width: selected ? 2 : 1),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: kn.textLink),
              const SizedBox(width: KnSize.space12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(title, style: text.label, maxLines: 2),
                  if (sub != null && sub.isNotEmpty)
                    CustomBaseTextWidget(sub, style: text.caption, color: kn.textSecondary, maxLines: 1),
                ],
              ),
            ),
            if (selected) Icon(LucideIcons.check, size: 20, color: kn.actionPrimary),
          ],
        ),
      ),
    );
  }
}
