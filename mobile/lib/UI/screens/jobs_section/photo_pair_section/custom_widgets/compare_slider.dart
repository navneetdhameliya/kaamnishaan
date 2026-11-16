import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M22 before (left of the line) over after (right); drag anywhere to move the line.
class CompareSlider extends StatelessWidget {
  const CompareSlider({super.key, required this.beforeUrl, required this.afterUrl, required this.split, required this.onDrag});

  final String? beforeUrl;
  final String? afterUrl;
  final double split;
  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    Widget tag(String label, Color bg) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
          child: CustomBaseTextWidget(label, style: text.labelSm, color: KnPrimitive.cream50),
        );
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final x = w * split;
        return GestureDetector(
          key: const ValueKey('compare'),
          onHorizontalDragUpdate: (d) => onDrag(d.localPosition.dx / w),
          onTapDown: (d) => onDrag(d.localPosition.dx / w),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(KnSize.radiusLg),
            child: Stack(
              fit: StackFit.expand,
              children: [
                KnCoverImage(url: afterUrl, placeholderIcon: LucideIcons.image),
                ClipRect(
                  clipper: _LeftClip(x),
                  child: KnCoverImage(url: beforeUrl, placeholderIcon: LucideIcons.image),
                ),
                Positioned(left: x - 1.5, top: 0, bottom: 0, child: Container(width: 3, color: KnPrimitive.cream50)),
                Positioned(
                  left: x - 26,
                  top: c.maxHeight / 2 - 26,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: KnPrimitive.cream50, shape: BoxShape.circle, boxShadow: KnShadow.md),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.chevronLeft, size: 18, color: KnPrimitive.mocha950),
                        Icon(LucideIcons.chevronRight, size: 18, color: KnPrimitive.mocha950),
                      ],
                    ),
                  ),
                ),
                Positioned(left: 12, top: 12, child: tag(LangKeys.cameraStageBefore.tr, KnPrimitive.mocha950.withValues(alpha: 0.7))),
                Positioned(right: 12, top: 12, child: tag(LangKeys.cameraStageAfter.tr, KnPrimitive.green650)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LeftClip extends CustomClipper<Rect> {
  _LeftClip(this.x);

  final double x;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x, size.height);

  @override
  bool shouldReclip(_LeftClip old) => old.x != x;
}
