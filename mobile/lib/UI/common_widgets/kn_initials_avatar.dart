import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';

/// Round avatar: the photo if there is one, else the initials, else a person icon.
class KnInitialsAvatar extends StatelessWidget {
  const KnInitialsAvatar({super.key, required this.initials, this.size = 48, this.image, this.borderWidth = 2});

  final String initials;
  final double size;
  final ImageProvider? image;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final style = size >= 80 ? context.knText.h1 : context.knText.label;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kn.bgSubtle,
        shape: BoxShape.circle,
        border: Border.all(color: KnPrimitive.mocha300, width: borderWidth),
        image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: image != null
          ? null
          : initials.isEmpty
              ? Icon(LucideIcons.user, size: size * 0.45, color: kn.textSecondary)
              : CustomBaseTextWidget(initials, style: style),
    );
  }
}
