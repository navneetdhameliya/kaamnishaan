import 'package:flutter/material.dart';

import '../theme/kn_app_theme.dart';

class CommonLoader extends StatelessWidget {
  const CommonLoader({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox.square(
          dimension: size,
          child: CircularProgressIndicator(strokeWidth: 3, color: color ?? context.kn.actionPrimary),
        ),
      );
}
