import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M19 "2/5" ring in the dark header.
class ProofRing extends StatelessWidget {
  const ProofRing({super.key, required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 80,
        height: 80,
        child: CustomPaint(
          painter: _RingPainter(total == 0 ? 0 : done / total),
          child: Center(
            child: CustomBaseTextWidget('$done/$total', style: context.knText.h2, color: KnPrimitive.cream50),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final track = Paint()
      ..color = KnPrimitive.cream100.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fill = Paint()
      ..color = KnPrimitive.sage500
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    if (value > 0) canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value;
}
