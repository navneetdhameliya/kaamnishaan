import 'package:flutter/material.dart';

import '../theme/kn_app_theme.dart';

/// Step dots: the current step is a 24 × 8 bar, the others 8 × 8 dots.
class KnProgressDots extends StatelessWidget {
  const KnProgressDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Semantics(
      label: '${index + 1} / $count',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? kn.actionPrimary : kn.borderStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
