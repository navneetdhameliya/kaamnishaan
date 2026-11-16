import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/kn_app_theme.dart';

/// A job or site picture from a link, with a calm placeholder while it loads or when there is none.
class KnCoverImage extends StatelessWidget {
  const KnCoverImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 0,
    this.placeholderIcon = LucideIcons.house,
  });

  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final iconSize = ((height ?? 56) * 0.4).clamp(16.0, 40.0);
    final placeholder = Container(
      width: width,
      height: height,
      color: kn.bgSubtle,
      alignment: Alignment.center,
      child: Icon(placeholderIcon, size: iconSize, color: kn.textSecondary),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? placeholder
          : Image.network(
              url!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : placeholder,
            ),
    );
  }
}
