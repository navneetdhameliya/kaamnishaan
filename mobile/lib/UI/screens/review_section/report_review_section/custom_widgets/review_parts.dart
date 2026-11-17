import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

class ReviewChip extends StatelessWidget {
  const ReviewChip({super.key, required this.icon, required this.label, this.background, this.foreground});

  final IconData icon;
  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final fg = foreground ?? kn.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? kn.actionSecondary,
        borderRadius: BorderRadius.circular(KnSize.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          CustomBaseTextWidget(label, style: context.knText.labelSm, color: fg),
        ],
      ),
    );
  }
}

/// The photos in a row, BEFORE / AFTER on each; tap one for its details.
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({super.key, required this.photos, required this.onTap});

  final List<EvidenceOutModel> photos;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    String tag(String stage) => switch (stage) {
          'before' => LangKeys.cameraStageBefore.tr,
          'after' => LangKeys.cameraStageAfter.tr,
          _ => LangKeys.cameraStageDuring.tr,
        }.toUpperCase();
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, _) => const SizedBox(width: KnSize.space8),
        itemBuilder: (context, i) => CustomInkWell(
          key: ValueKey('review-photo-$i'),
          onTap: () => onTap(i),
          borderRadius: BorderRadius.circular(KnSize.radiusMd),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KnSize.radiusMd),
            child: SizedBox(
              width: 88,
              height: 92,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  KnCoverImage(url: photos[i].thumbUrl ?? photos[i].url),
                  if (photos[i].stage != 'during')
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: KnPrimitive.mocha950.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(KnSize.radiusFull),
                        ),
                        child: CustomBaseTextWidget(tag(photos[i].stage), style: text.captionStrong, color: KnPrimitive.cream50),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ProofRowData {
  const ProofRowData({
    required this.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.warn = false,
  });

  final String key;
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool warn;
}

/// Photos 6 · Checklist 11 of 12 · Voice notes 2.
class ProofRows extends StatelessWidget {
  const ProofRows({super.key, required this.rows});

  final List<ProofRowData> rows;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
        boxShadow: KnShadow.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, color: kn.borderDefault),
            CustomInkWell(
              key: ValueKey('review-row-${r.key}'),
              onTap: r.onTap,
              child: SizedBox(
                height: 56,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: KnSize.space12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
                        child: Icon(r.icon, size: 16, color: kn.textPrimary),
                      ),
                      const SizedBox(width: KnSize.space12),
                      Expanded(child: CustomBaseTextWidget(r.label, style: text.label)),
                      CustomBaseTextWidget(r.value, style: text.label, color: r.warn ? kn.statusWarning : kn.textPrimary),
                      const SizedBox(width: KnSize.space8),
                      Icon(LucideIcons.chevronRight, size: 20, color: kn.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "AI check · 1 thing to look at — Drain pipe has a leak · no photo".
class AiCheckBanner extends StatelessWidget {
  const AiCheckBanner({super.key, required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.statusWarningBg,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.statusWarning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.circleAlert, size: 18, color: kn.statusWarning),
          const SizedBox(width: KnSize.space8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(title, style: text.captionStrong, color: kn.statusWarning),
                for (final l in lines.take(3)) ...[
                  const SizedBox(height: 2),
                  CustomBaseTextWidget(l, style: text.label),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Work done" and its words, with the pencil when it can still be changed.
class WordsCard extends StatelessWidget {
  const WordsCard({super.key, required this.title, required this.body, this.onEdit});

  final String title;
  final String body;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
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
          Row(
            children: [
              Expanded(child: CustomBaseTextWidget(title, style: text.captionStrong, color: kn.textSecondary)),
              if (onEdit != null) EditPencil(onTap: onEdit!),
            ],
          ),
          const SizedBox(height: KnSize.space4),
          CustomBaseTextWidget(body, style: text.bodyLg),
        ],
      ),
    );
  }
}

/// The pencil on the words opens the editor (M32).
class EditPencil extends StatelessWidget {
  const EditPencil({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CustomInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(LucideIcons.pencil, size: 18, color: context.kn.textSecondary),
        ),
      );
}
