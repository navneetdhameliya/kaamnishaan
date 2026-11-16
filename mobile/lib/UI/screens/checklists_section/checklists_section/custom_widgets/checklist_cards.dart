import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M24 card of the list to do now: the job's picture with the machine, name, size and progress.
class ActiveChecklistCard extends StatelessWidget {
  const ActiveChecklistCard({
    super.key,
    required this.name,
    required this.meta,
    required this.answered,
    required this.total,
    required this.onTap,
    this.coverUrl,
    this.equipment,
  });

  final String name;
  final String meta;
  final int answered;
  final int total;
  final VoidCallback onTap;
  final String? coverUrl;
  final String? equipment;

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
        padding: const EdgeInsets.all(KnSize.space16),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: kn.actionPrimary, width: 2),
          boxShadow: KnShadow.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  KnCoverImage(url: coverUrl, height: 120, radius: 12, placeholderIcon: LucideIcons.airVent),
                  if (equipment != null && equipment!.isNotEmpty)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
                        decoration: BoxDecoration(
                          color: KnPrimitive.cream50,
                          borderRadius: BorderRadius.circular(KnSize.radiusFull),
                        ),
                        child: CustomBaseTextWidget(equipment!, style: text.labelSm, color: KnPrimitive.mocha950),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: KnSize.space12),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: kn.actionPrimary, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                  child: Icon(LucideIcons.listChecks, size: 24, color: kn.textOnAction),
                ),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomBaseTextWidget(name, style: text.h3, maxLines: 1),
                      CustomBaseTextWidget(meta, style: text.caption, color: kn.textSecondary, maxLines: 1),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: KnSize.space12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : answered / total,
                      minHeight: 6,
                      backgroundColor: kn.bgSubtle,
                      color: kn.actionPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: KnSize.space8),
                CustomBaseTextWidget(
                  LangKeys.hubOf.trParams({'done': '$answered', 'total': '$total'}),
                  style: text.labelSm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// M24 row for any other list: done (green) or waiting.
class ChecklistRowCard extends StatelessWidget {
  const ChecklistRowCard({super.key, required this.name, required this.line, required this.done, required this.onTap});

  final String name;
  final String line;
  final bool done;
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
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(
          color: done ? kn.statusSuccessBg : kn.bgSurface,
          borderRadius: radius,
          border: Border.all(color: done ? kn.statusSuccess.withValues(alpha: 0.5) : kn.borderDefault),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: done ? kn.statusSuccess : kn.bgSubtle,
                borderRadius: BorderRadius.circular(KnSize.radiusMd),
              ),
              child: Icon(
                done ? LucideIcons.check : LucideIcons.listChecks,
                size: 24,
                color: done ? KnPrimitive.cream50 : kn.textPrimary,
              ),
            ),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(name, style: text.h3, maxLines: 1),
                  CustomBaseTextWidget(
                    line,
                    style: text.caption,
                    color: done ? kn.statusSuccess : kn.textSecondary,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            if (done)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
                decoration: BoxDecoration(color: kn.statusSuccess, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.check, size: 14, color: KnPrimitive.cream50),
                    const SizedBox(width: KnSize.space4),
                    CustomBaseTextWidget(LangKeys.statusCompleted.tr, style: text.labelSm, color: KnPrimitive.cream50),
                  ],
                ),
              )
            else
              Icon(LucideIcons.chevronRight, size: 20, color: kn.textPrimary),
          ],
        ),
      ),
    );
  }
}
