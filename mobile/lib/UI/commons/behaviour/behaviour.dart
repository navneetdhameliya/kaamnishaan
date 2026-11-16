import 'package:flutter/material.dart';

/// Removes the over-scroll glow (as in Neho).
class KnScrollBehavior extends ScrollBehavior {
  const KnScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}
