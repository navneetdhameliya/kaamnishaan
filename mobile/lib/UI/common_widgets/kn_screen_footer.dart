import 'package:flutter/material.dart';

import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';

/// The white bar at the bottom of a screen that holds its buttons (Figma "Footer").
class KnScreenFooter extends StatelessWidget {
  const KnScreenFooter({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return DecoratedBox(
      decoration: BoxDecoration(color: kn.bgSurface, border: Border(top: BorderSide(color: kn.borderDefault))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(KnSize.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: KnSize.space8),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
