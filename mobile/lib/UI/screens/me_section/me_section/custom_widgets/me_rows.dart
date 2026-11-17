import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../me_controller.dart';

/// "14 Jobs done · 96 Photos · 12 Reports".
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.stats});

  final List<MeStat> stats;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: KnSize.space16),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        boxShadow: KnShadow.md,
      ),
      child: Row(
        children: [
          for (final s in stats)
            Expanded(
              child: Column(
                children: [
                  CustomBaseTextWidget('${s.value}', style: text.h2),
                  CustomBaseTextWidget(s.label, style: text.caption, color: kn.textSecondary, maxLines: 1),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A white card of rows with lines between them.
class MeCard extends StatelessWidget {
  const MeCard({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
        boxShadow: KnShadow.sm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: kn.borderDefault),
            rows[i],
          ],
        ],
      ),
    );
  }
}

/// One row: icon, label, a value or red count, and an arrow.
class MeRow extends StatelessWidget {
  const MeRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.badge = 0,
    this.danger = false,
    this.chevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? value;
  final int badge;
  final bool danger;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final fg = danger ? kn.statusDanger : kn.textPrimary;
    return CustomInkWell(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: KnSize.space12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: danger ? kn.statusDangerBg : kn.actionSecondary),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: KnSize.space12),
              Expanded(child: CustomBaseTextWidget(label, style: text.label, color: fg, maxLines: 1)),
              if (value != null && value!.isNotEmpty) CustomBaseTextWidget(value!, style: text.body, color: kn.textSecondary),
              if (badge > 0)
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  height: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: kn.statusDanger, borderRadius: BorderRadius.circular(12)),
                  child: CustomBaseTextWidget('$badge', style: text.labelSm, color: kn.textOnAction),
                ),
              if (chevron) ...[
                const SizedBox(width: KnSize.space8),
                Icon(LucideIcons.chevronRight, size: 20, color: kn.textSecondary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
