import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

class KnTabItem {
  const KnTabItem({required this.icon, required this.label, this.key});

  final IconData icon;
  final String label;
  final Key? key;
}

/// Figma "Tab bar": a floating rounded bar with the tabs, and a round camera button beside it.
/// Two tabs (technician) fill the whole tab when selected; more tabs (manager) light up a pill
/// behind the icon. [index] -1 selects no tab; [captureActive] fills the camera button (M19).
class KnGlassTabBar extends StatelessWidget {
  const KnGlassTabBar({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
    required this.onCapture,
    required this.captureLabel,
    this.captureActive = false,
  });

  final List<KnTabItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onCapture;
  final String captureLabel;
  final bool captureActive;

  static const _shadow = [BoxShadow(color: Color(0x291F140D), offset: Offset(0, 8), blurRadius: 24)];

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final wide = items.length <= 2;
    final capture = wide ? 64.0 : 56.0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KnSize.space12, KnSize.space4, KnSize.space12, KnSize.space12),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 64,
                padding: EdgeInsets.symmetric(horizontal: wide ? 6 : 4, vertical: 4),
                decoration: BoxDecoration(
                  color: kn.bgSurface,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: kn.borderDefault),
                  boxShadow: _shadow,
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0 && wide) const SizedBox(width: KnSize.space4),
                      Expanded(child: _tab(context, items[i], i == index, wide, () => onTap(i))),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(width: wide ? 10 : KnSize.space8),
            CustomInkWell(
              key: const ValueKey('capture-button'),
              onTap: onCapture,
              borderRadius: BorderRadius.circular(capture / 2),
              semanticLabel: captureLabel,
              child: Ink(
                width: capture,
                height: capture,
                decoration: BoxDecoration(
                  color: captureActive ? kn.actionPrimary : kn.bgSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: captureActive ? kn.actionPrimary : kn.borderDefault),
                  boxShadow: _shadow,
                ),
                child: Icon(
                  LucideIcons.camera,
                  size: wide ? 26 : 24,
                  color: captureActive ? kn.textOnAction : kn.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, KnTabItem item, bool selected, bool wide, VoidCallback onTap) {
    final kn = context.kn;
    final text = context.knText.caption.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400);
    final color = selected ? kn.textPrimary : kn.textSecondary;
    final icon = Icon(item.icon, size: 24, color: color);
    return CustomInkWell(
      key: item.key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      semanticLabel: item.label,
      child: Ink(
        height: 54,
        decoration: BoxDecoration(
          color: selected && wide ? kn.bgSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (wide)
              icon
            else
              Container(
                width: 48,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? kn.bgSubtle : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: icon,
              ),
            const SizedBox(height: 2),
            CustomBaseTextWidget(item.label, style: text, color: color, maxLines: 1),
          ],
        ),
      ),
    );
  }
}
