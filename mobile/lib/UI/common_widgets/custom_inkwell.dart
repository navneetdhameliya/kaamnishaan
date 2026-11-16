import 'package:flutter/material.dart';

/// Tap area with the ripple clipped to the shape.
class CustomInkWell extends StatelessWidget {
  const CustomInkWell({super.key, required this.child, this.onTap, this.borderRadius, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, borderRadius: borderRadius, child: child),
      ),
    );
  }
}
