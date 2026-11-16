import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// The big on-screen number pad used for the phone number and the SMS code (no phone keyboard).
class KnNumberKeypad extends StatelessWidget {
  const KnNumberKeypad({super.key, required this.onDigit, required this.onBackspace});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space4), // + 16 page padding = 20 as in Figma
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: KnSize.space8),
            Row(
              children: [
                for (var c = 0; c < 3; c++) ...[
                  if (c > 0) const SizedBox(width: KnSize.space16),
                  Expanded(child: _Key(value: rows[r][c], onDigit: onDigit, onBackspace: onBackspace)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.value, required this.onDigit, required this.onBackspace});

  final String value;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox(height: 64);
    final kn = context.kn;
    final isBack = value == '<';
    final radius = BorderRadius.circular(KnSize.radiusMd);
    return CustomInkWell(
      key: ValueKey('key-$value'),
      onTap: isBack ? onBackspace : () => onDigit(value),
      borderRadius: radius,
      semanticLabel: isBack ? 'Delete' : value,
      child: Ink(
        height: 64,
        decoration: BoxDecoration(color: isBack ? Colors.transparent : kn.bgSurface, borderRadius: radius),
        child: Center(
          child: isBack
              ? Icon(LucideIcons.delete, size: 26, color: kn.textPrimary)
              : Text(value, style: context.knText.h2.copyWith(fontSize: 28, color: kn.textPrimary)),
        ),
      ),
    );
  }
}
