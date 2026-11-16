import 'package:flutter/material.dart';

import '../../../theme/kn_app_theme.dart';

/// All text goes through this widget (Neho standard). Style comes from the token text styles;
/// colour defaults to text/primary.
class CustomBaseTextWidget extends StatelessWidget {
  const CustomBaseTextWidget(
    this.title, {
    super.key,
    this.style,
    this.color,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String title;
  final TextStyle? style;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final base = style ?? context.knText.body;
    return Text(
      title,
      style: base.copyWith(color: color ?? base.color ?? context.kn.textPrimary),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: true,
    );
  }
}
