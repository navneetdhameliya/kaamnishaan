import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../camera_controller.dart';

/// M20 bottom panel: the latest photos with the total, then gallery · shutter · Done.
class CameraControls extends StatelessWidget {
  const CameraControls({
    super.key,
    required this.thumbs,
    required this.total,
    required this.busy,
    required this.onShutter,
    required this.onGallery,
    required this.onDone,
  });

  final List<CameraThumb> thumbs;
  final int total;
  final bool busy;
  final VoidCallback onShutter;
  final VoidCallback onGallery;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    return Container(
      color: KnPrimitive.mocha950.withValues(alpha: 0.88),
      padding: EdgeInsets.fromLTRB(KnSize.space16, KnSize.space16, KnSize.space16, KnSize.space16 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                for (var i = 0; i < thumbs.length; i++) ...[
                  if (i > 0) const SizedBox(width: KnSize.space8),
                  _thumb(thumbs[i], latest: i == thumbs.length - 1),
                ],
                const Spacer(),
                if (total > 0)
                  Container(
                    key: const ValueKey('photo-count'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: KnPrimitive.cream100.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(KnSize.radiusFull),
                    ),
                    child: CustomBaseTextWidget('$total', style: text.labelSm, color: KnPrimitive.cream50),
                  ),
              ],
            ),
          ),
          const SizedBox(height: KnSize.space16),
          SizedBox(
            height: 84,
            child: Row(
              children: [
                CustomInkWell(
                  key: const ValueKey('camera-gallery'),
                  onTap: onGallery,
                  borderRadius: BorderRadius.circular(28),
                  semanticLabel: LangKeys.cameraGallery.tr,
                  child: Ink(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: KnPrimitive.cream100.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.image, size: 24, color: KnPrimitive.cream50),
                  ),
                ),
                const Spacer(),
                CustomInkWell(
                  key: const ValueKey('shutter'),
                  onTap: onShutter,
                  borderRadius: BorderRadius.circular(42),
                  semanticLabel: LangKeys.cameraShutter.tr,
                  child: Ink(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: KnPrimitive.cream50, width: 4),
                    ),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: busy ? 56 : 66,
                        height: busy ? 56 : 66,
                        decoration: const BoxDecoration(color: KnPrimitive.cream50, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                CustomInkWell(
                  key: const ValueKey('camera-done'),
                  onTap: onDone,
                  borderRadius: BorderRadius.circular(KnSize.radiusFull),
                  semanticLabel: LangKeys.cameraDone.tr,
                  child: Ink(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
                    decoration: BoxDecoration(
                      color: KnPrimitive.green650,
                      borderRadius: BorderRadius.circular(KnSize.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.check, size: 20, color: KnPrimitive.cream100),
                        const SizedBox(width: 6),
                        CustomBaseTextWidget(LangKeys.cameraDone.tr, style: text.label, color: KnPrimitive.cream100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(CameraThumb t, {required bool latest}) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: latest ? Border.all(color: KnPrimitive.green650, width: 2) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(latest ? 8 : 10),
          child: t.path != null
              ? Image.file(File(t.path!), fit: BoxFit.cover, cacheWidth: 160, errorBuilder: (_, _, _) => const SizedBox())
              : KnCoverImage(url: t.url, width: 52, height: 52, placeholderIcon: LucideIcons.image),
        ),
      );
}
