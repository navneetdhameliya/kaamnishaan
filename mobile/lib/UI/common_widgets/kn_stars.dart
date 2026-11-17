import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/kn_app_theme.dart';

/// Five stars, [rating] of them filled (warm orange); the rest grey. Read as "4 / 5".
/// Drawn, not a font icon, so they look the same on every phone.
class KnStars extends StatelessWidget {
  const KnStars({super.key, required this.rating, this.size = 18, this.onDark = false});

  final int rating;
  final double size;

  /// On the dark header the empty stars are lighter.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final empty = onDark ? kn.textSecondary : kn.borderStrong;
    return Semantics(
      label: '$rating / 5',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++) ...[
              CustomPaint(
                size: Size.square(size),
                painter: _Star(i <= rating ? kn.statusWarning : empty),
              ),
              if (i < 5) SizedBox(width: size / 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _Star extends CustomPainter {
  _Star(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2 + size.height * 0.04);
    final outer = size.width / 2;
    final inner = outer * 0.45;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_Star old) => old.color != color;
}
