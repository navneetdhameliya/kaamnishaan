import 'package:flutter/material.dart';

import '../theme/kn_app_theme.dart';

/// Five stars, [rating] of them filled (warm orange); the rest grey. Read as "4 of 5 stars".
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
              Icon(Icons.star_rounded, size: size * 1.15, color: i <= rating ? kn.statusWarning : empty),
              if (i < 5) SizedBox(width: size / 10),
            ],
          ],
        ),
      ),
    );
  }
}
