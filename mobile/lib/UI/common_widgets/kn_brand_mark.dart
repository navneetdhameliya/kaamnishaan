import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../infrastructure/commons/constants/image_constants.dart';

/// The KaamNishaan mark (Figma Brand/Mark). [onDark] adds the cream ring used on dark backgrounds.
class KnBrandMark extends StatelessWidget {
  const KnBrandMark({super.key, this.size = 48, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        onDark ? ImageConstants.brandMarkDark : ImageConstants.brandMarkLight,
        width: size,
        height: size,
        semanticsLabel: 'KaamNishaan',
      );
}
