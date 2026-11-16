import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';

/// A grey placeholder block for loading states.
class CommonShimmer extends StatelessWidget {
  const CommonShimmer({super.key, this.width = double.infinity, required this.height, this.radius = KnSize.radiusMd});

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Shimmer.fromColors(
      baseColor: kn.bgSubtle,
      highlightColor: kn.bgSurface,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}
