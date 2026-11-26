import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../assistant_controller.dart';

/// What the person asked: a dark bubble.
class QuestionBubble extends StatelessWidget {
  const QuestionBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 10),
          decoration: BoxDecoration(color: kn.actionPrimary, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
          child: CustomBaseTextWidget(text, style: context.knText.bodyLg, color: kn.textOnAction),
        ),
      ),
    );
  }
}

/// The answer: a light bubble with the reports and jobs it came from, and a sparkle beside it.
class AnswerBubble extends StatelessWidget {
  const AnswerBubble({super.key, required this.message, required this.controller});

  final AssistantMessageOutModel message;
  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final source = controller.sourcesLine(message);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const AiMark(),
        const SizedBox(width: KnSize.space8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(KnSize.space12),
            decoration: BoxDecoration(
              color: kn.bgSurface,
              borderRadius: BorderRadius.circular(KnSize.radiusLg),
              border: Border.all(color: kn.borderDefault),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(message.text, style: text.bodyLg),
                for (final r in message.reports ?? const <SourceReportModel>[]) ...[
                  const SizedBox(height: KnSize.space12),
                  _SourceCard(
                    key: ValueKey('source-report-${r.id}'),
                    coverUrl: r.coverUrl,
                    title: LangKeys.aiReportN.trParams({'n': r.number}),
                    line: controller.reportLine(r),
                    onTap: () => controller.onReportTap(r),
                  ),
                ],
                for (final j in message.jobs ?? const <SourceJobModel>[]) ...[
                  const SizedBox(height: KnSize.space12),
                  _JobSource(key: ValueKey('source-job-${j.id}'), job: j, controller: controller),
                ],
                if (source != null) ...[
                  const SizedBox(height: KnSize.space8),
                  Row(
                    children: [
                      Icon(LucideIcons.fileText, size: 14, color: kn.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(child: CustomBaseTextWidget(source, style: text.caption, color: kn.textSecondary)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The small dark circle with a sparkle.
class AiMark extends StatelessWidget {
  const AiMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: kn.actionPrimary, shape: BoxShape.circle),
      child: Icon(LucideIcons.sparkle, size: size / 2.2, color: kn.textOnAction),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({super.key, required this.coverUrl, required this.title, required this.line, required this.onTap});

  final String? coverUrl;
  final String title;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusMd);
    return CustomInkWell(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: title,
      child: Ink(
        padding: const EdgeInsets.all(KnSize.space8),
        decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: radius),
        child: Row(
          children: [
            KnCoverImage(url: coverUrl, width: 52, height: 52, radius: KnSize.radiusSm, placeholderIcon: LucideIcons.fileText),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(title, style: context.knText.label),
                  CustomBaseTextWidget(line, style: context.knText.caption, color: kn.textSecondary),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: kn.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _JobSource extends StatelessWidget {
  const _JobSource({super.key, required this.job, required this.controller});

  final SourceJobModel job;
  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusMd);
    return CustomInkWell(
      onTap: () => controller.onJobTap(job),
      borderRadius: radius,
      semanticLabel: job.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final url in job.photos) ...[
                KnCoverImage(url: url, width: 64, height: 56, radius: KnSize.radiusSm, placeholderIcon: LucideIcons.image),
                const SizedBox(width: KnSize.space8),
              ],
              if (job.missing.isNotEmpty)
                CustomInkWell(
                  key: ValueKey('ai-missing-${job.id}'),
                  onTap: () => controller.onMissingTap(job),
                  borderRadius: BorderRadius.circular(KnSize.radiusSm),
                  semanticLabel: controller.missingLine(job),
                  child: Container(
                    width: 64,
                    height: 56,
                    decoration: BoxDecoration(
                      color: kn.statusWarningBg,
                      borderRadius: BorderRadius.circular(KnSize.radiusSm),
                      border: Border.all(color: kn.statusWarning),
                    ),
                    child: Icon(LucideIcons.camera, size: 20, color: kn.statusWarning),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          CustomBaseTextWidget(
            '${job.customer} · ${controller.missingLine(job)}',
            style: context.knText.caption,
            color: job.missing.isEmpty ? kn.textSecondary : kn.statusWarning,
          ),
        ],
      ),
    );
  }
}

/// M36 "Chat is paused" (Figma 248:2383).
class PausedCard extends StatelessWidget {
  const PausedCard({super.key, required this.controller});

  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space24),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.statusWarning, width: 1.5),
        boxShadow: KnShadow.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: kn.statusWarningBg, shape: BoxShape.circle),
            child: Icon(LucideIcons.sparkle, size: 26, color: kn.statusWarning),
          ),
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(LangKeys.aiPaused.tr, style: text.h2, textAlign: TextAlign.center),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(controller.pausedBody, style: text.body, color: kn.textSecondary, textAlign: TextAlign.center),
          const SizedBox(height: KnSize.space16),
          ClipRRect(
            borderRadius: BorderRadius.circular(KnSize.radiusFull),
            child: Stack(
              children: [
                Container(height: 8, color: kn.actionSecondary),
                FractionallySizedBox(
                  widthFactor: controller.usedFraction,
                  child: Container(height: 8, color: kn.statusWarning),
                ),
              ],
            ),
          ),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(controller.usedLine, style: text.caption, color: kn.textSecondary),
          const SizedBox(height: KnSize.space16),
          IntrinsicWidth(
            child: KnCustomButton(
              key: const ValueKey('ai-upgrade'),
              text: LangKeys.aiUpgrade.tr,
              icon: LucideIcons.sparkles,
              onTap: controller.onUpgradeTap,
            ),
          ),
          const SizedBox(height: KnSize.space8),
          IntrinsicWidth(
            child: KnCustomButton(
              key: const ValueKey('ai-not-now'),
              text: LangKeys.aiNotNow.tr,
              variant: KnButtonVariant.ghost,
              onTap: controller.onNotNow,
            ),
          ),
        ],
      ),
    );
  }
}
