import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/shared/job_arguments.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../report_making_controller.dart';

/// The sparkle in rings, the photos it reads, the progress and the steps.
class MakingView extends StatelessWidget {
  const MakingView({super.key, required this.controller});

  final ReportMakingController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final thumbs = controller.args.thumbs.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox.square(
            dimension: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusSuccessBg),
                ),
                Container(
                  width: 136,
                  height: 136,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kn.statusSuccess.withValues(alpha: 0.14),
                  ),
                ),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionPrimary, boxShadow: KnShadow.lg),
                  child: Icon(LucideIcons.sparkle, size: 32, color: kn.textOnAction),
                ),
              ],
            ),
          ),
        ),
        if (thumbs.isNotEmpty) ...[
          const SizedBox(height: KnSize.space12),
          Center(
            child: SizedBox(
              height: 36,
              width: 36 + (thumbs.length - 1) * 24.0,
              child: Stack(
                children: [
                  for (var i = 0; i < thumbs.length; i++)
                    Positioned(
                      left: i * 24.0,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: kn.bgCanvas, width: 2),
                        ),
                        child: ClipOval(child: KnCoverImage(url: thumbs[i], width: 32, height: 32)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: KnSize.space16),
        CustomBaseTextWidget(LangKeys.reportMaking.tr, style: text.h1, textAlign: TextAlign.center),
        const SizedBox(height: KnSize.space4),
        CustomBaseTextWidget(
          LangKeys.reportAboutSeconds.tr,
          style: text.bodyLg,
          color: kn.textSecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: KnSize.space16),
        Obx(
          () => ClipRRect(
            borderRadius: BorderRadius.circular(KnSize.radiusFull),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: controller.progress.clamp(0.08, 1.0)),
              duration: const Duration(milliseconds: 400),
              builder: (context, v, _) => LinearProgressIndicator(
                key: const ValueKey('report-progress'),
                value: v,
                minHeight: 6,
                color: kn.actionPrimary,
                backgroundColor: kn.actionSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: KnSize.space16),
        Container(
          padding: const EdgeInsets.all(KnSize.space16),
          decoration: BoxDecoration(
            color: kn.bgSurface,
            borderRadius: BorderRadius.circular(KnSize.radiusLg),
            border: Border.all(color: kn.borderDefault),
            boxShadow: KnShadow.sm,
          ),
          child: Obx(
            () => Column(
              children: [
                for (final (i, r) in controller.rows.indexed) ...[
                  if (i > 0) const SizedBox(height: KnSize.space12),
                  _StepRow(row: r),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: KnSize.space16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.bell, size: 16, color: kn.textSecondary),
            const SizedBox(width: KnSize.space8),
            Flexible(
              child: CustomBaseTextWidget(LangKeys.reportCanLeave.tr, style: text.caption, color: kn.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.row});

  final MakeRow row;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final Widget mark = switch (row.state) {
      RowState.done => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusSuccess),
          child: Icon(LucideIcons.check, size: 16, color: kn.textOnAction),
        ),
      RowState.running => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
          child: Icon(LucideIcons.rotateCw, size: 16, color: kn.textPrimary),
        ),
      RowState.waiting => Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kn.borderStrong, width: 2)),
        ),
    };
    return Row(
      children: [
        mark,
        const SizedBox(width: KnSize.space12),
        Expanded(
          child: CustomBaseTextWidget(
            row.text,
            style: row.state == RowState.running ? text.label : text.body,
            color: row.state == RowState.waiting ? kn.textSecondary : kn.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// "Could not make the report": the proof is safe, try again.
class FailedView extends StatelessWidget {
  const FailedView({super.key, required this.args});

  final ReportArguments args;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final thumbs = args.thumbs;
    final shown = thumbs.take(3).toList();
    final counts = [
      LangKeys.reportCountPhotos.trParams({'n': '${args.photos}'}),
      if (args.checklists > 0) LangKeys.reportCountChecklists.trParams({'n': '${args.checklists}'}),
      if (args.notes > 0) LangKeys.reportCountNotes.trParams({'n': '${args.notes}'}),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: SizedBox.square(
            dimension: 120,
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusDangerBg),
                  child: Icon(LucideIcons.cloudOff, size: 44, color: kn.statusDanger),
                ),
                Positioned(
                  right: 0,
                  bottom: 4,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: kn.bgSurface, boxShadow: KnShadow.sm),
                    child: Icon(LucideIcons.circleAlert, size: 20, color: kn.statusDanger),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KnSize.space24),
        CustomBaseTextWidget(LangKeys.reportFailedTitle.tr, style: text.h1, textAlign: TextAlign.center),
        const SizedBox(height: KnSize.space8),
        CustomBaseTextWidget(
          LangKeys.reportFailedBody.tr,
          style: text.bodyLg,
          color: kn.textSecondary,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: KnSize.space24),
        Container(
          padding: const EdgeInsets.all(KnSize.space16),
          decoration: BoxDecoration(
            color: kn.bgSurface,
            borderRadius: BorderRadius.circular(KnSize.radiusLg),
            border: Border.all(color: kn.borderDefault),
            boxShadow: KnShadow.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shown.isNotEmpty) ...[
                Row(
                  children: [
                    for (final t in shown) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(KnSize.radiusMd),
                        child: KnCoverImage(url: t, width: 56, height: 56),
                      ),
                      const SizedBox(width: KnSize.space8),
                    ],
                    if (args.photos > shown.length)
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: kn.actionSecondary,
                          borderRadius: BorderRadius.circular(KnSize.radiusMd),
                        ),
                        child: CustomBaseTextWidget('+${args.photos - shown.length}', style: text.label),
                      ),
                  ],
                ),
                const SizedBox(height: KnSize.space12),
              ],
              for (final c in counts) ...[
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusSuccess),
                      child: Icon(LucideIcons.check, size: 14, color: kn.textOnAction),
                    ),
                    const SizedBox(width: KnSize.space12),
                    CustomBaseTextWidget(c, style: text.body),
                  ],
                ),
                const SizedBox(height: KnSize.space8),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kn.actionSecondary,
                  borderRadius: BorderRadius.circular(KnSize.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.cloudCheck, size: 14, color: kn.textSecondary),
                    const SizedBox(width: 6),
                    CustomBaseTextWidget(LangKeys.reportSaved.tr, style: text.labelSm, color: kn.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
