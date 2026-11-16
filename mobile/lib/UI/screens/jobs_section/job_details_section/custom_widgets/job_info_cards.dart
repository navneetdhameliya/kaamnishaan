import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/shared/text_utils.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M15 "Dr. Anita Rao · Clinic owner": the person to meet.
class JobContactCard extends StatelessWidget {
  const JobContactCard({super.key, required this.name, this.title});

  final String name;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 10),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: KnPrimitive.sage100, shape: BoxShape.circle),
            child: CustomBaseTextWidget(TextUtils.initials(name), style: text.label, color: KnPrimitive.sage700),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(name, style: text.label, maxLines: 1),
                if (title != null && title!.isNotEmpty)
                  CustomBaseTextWidget(title!, style: text.caption, color: kn.textSecondary, maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// M15 amber "Problem · AC not cooling in room 2".
class JobProblemCard extends StatelessWidget {
  const JobProblemCard({super.key, required this.problem});

  final String problem;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 10),
      decoration: BoxDecoration(color: kn.statusWarningBg, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: kn.bgSurface, shape: BoxShape.circle),
            child: Icon(LucideIcons.circleAlert, size: 18, color: kn.statusWarning),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(LangKeys.jobProblem.tr, style: text.caption, color: kn.statusWarning),
                CustomBaseTextWidget(problem, style: text.label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// M15 "Equipment · Split AC · 1.5 ton · Room 2 · last service 12 Aug".
class JobEquipmentCard extends StatelessWidget {
  const JobEquipmentCard({super.key, required this.name, required this.info, required this.onTap, this.imageUrl});

  final String name;
  final String info;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: name,
      child: Ink(
        padding: const EdgeInsets.fromLTRB(KnSize.space8, KnSize.space8, KnSize.space12, KnSize.space8),
        decoration: BoxDecoration(color: kn.bgSurface, borderRadius: radius, border: Border.all(color: kn.borderDefault)),
        child: Row(
          children: [
            KnCoverImage(url: imageUrl, width: 64, height: 64, radius: 12, placeholderIcon: LucideIcons.airVent),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(LangKeys.jobEquipment.tr, style: text.caption, color: kn.textSecondary),
                  CustomBaseTextWidget(name, style: text.label, maxLines: 1),
                  if (info.isNotEmpty)
                    CustomBaseTextWidget(info, style: text.caption, color: kn.textSecondary, maxLines: 1),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 20, color: kn.textPrimary),
          ],
        ),
      ),
    );
  }
}
