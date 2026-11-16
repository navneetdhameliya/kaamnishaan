import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';

/// Round avatar: the photo if there is one, else the initials, else a person icon.
/// [url] is a photo link from the API; [image] a photo already in memory (just picked).
class KnInitialsAvatar extends StatelessWidget {
  const KnInitialsAvatar({
    super.key,
    required this.initials,
    this.size = 48,
    this.image,
    this.url,
    this.borderWidth = 2,
  });

  final String initials;
  final double size;
  final ImageProvider? image;
  final String? url;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final style = size >= 80
        ? context.knText.h1
        : size < 32
            ? context.knText.captionStrong.copyWith(fontSize: size * 0.42)
            : context.knText.label;
    final ImageProvider? photo = image ?? (url != null ? NetworkImage(url!) : null);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kn.bgSubtle,
        shape: BoxShape.circle,
        border: borderWidth == 0 ? null : Border.all(color: KnPrimitive.mocha300, width: borderWidth),
        image: photo == null ? null : DecorationImage(image: photo, fit: BoxFit.cover, onError: (_, _) {}),
      ),
      alignment: Alignment.center,
      child: photo != null
          ? null
          : initials.isEmpty
              ? Icon(LucideIcons.user, size: size * 0.45, color: kn.textSecondary)
              : CustomBaseTextWidget(initials, style: style),
    );
  }
}
