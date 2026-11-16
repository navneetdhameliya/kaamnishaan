import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/services/photo_queue_service.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_dashed_border.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../photo_gallery_controller.dart';

/// M21 photo square with the time it was taken; a photo still on the phone says so.
class GalleryPhotoTile extends StatelessWidget {
  const GalleryPhotoTile({super.key, required this.photo, required this.time, required this.onTap});

  final GalleryPhoto photo;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    final p = photo.pending;
    final (IconData icon, String label, Color bg) = switch (p?.state) {
      null => (LucideIcons.clock, time, KnPrimitive.mocha950.withValues(alpha: 0.7)),
      PendingState.sending => (LucideIcons.upload, LangKeys.gallerySending.tr, KnPrimitive.mocha950.withValues(alpha: 0.7)),
      PendingState.failed => (LucideIcons.rotateCw, LangKeys.galleryNotSent.tr, KnPrimitive.red600),
      PendingState.waiting => (LucideIcons.cloudUpload, LangKeys.galleryWaiting.tr, KnPrimitive.mocha950.withValues(alpha: 0.7)),
    };
    return CustomInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      semanticLabel: label,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (p != null)
              Image.file(File(p.path), fit: BoxFit.cover, cacheWidth: 320, errorBuilder: (_, _, _) => const SizedBox())
            else
              KnCoverImage(url: photo.server?.thumbUrl ?? photo.server?.url, placeholderIcon: LucideIcons.image),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: KnSize.space8, vertical: 2),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: KnPrimitive.cream50),
                      const SizedBox(width: KnSize.space4),
                      Flexible(
                        child: CustomBaseTextWidget(label, style: text.captionStrong, color: KnPrimitive.cream50, maxLines: 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// M21 dashed "+ Add photo" square.
class GalleryAddTile extends StatelessWidget {
  const GalleryAddTile({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return KnDashedBorder(
      color: kn.borderStrong,
      radius: 12,
      strokeWidth: 2,
      child: CustomInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        semanticLabel: LangKeys.galleryAddPhoto.tr,
        child: Ink(
          decoration: BoxDecoration(color: kn.bgSurface, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.plus, size: 28, color: kn.textPrimary),
              const SizedBox(height: KnSize.space4),
              CustomBaseTextWidget(LangKeys.galleryAddPhoto.tr, style: context.knText.labelSm),
            ],
          ),
        ),
      ),
    );
  }
}
