import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// Figma "Selection control": a 28 px box and its words; the whole row is the tap target (56 tall).
class KnCheckboxTile extends StatelessWidget {
  const KnCheckboxTile({super.key, required this.value, required this.label, required this.onChanged, this.hasError = false});

  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final border = hasError ? kn.statusDanger : kn.borderStrong;
    return CustomInkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(KnSize.radiusMd),
      semanticLabel: label,
      child: SizedBox(
        height: KnSize.tapTechnician,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: value ? kn.actionPrimary : kn.bgSurface,
                borderRadius: BorderRadius.circular(KnSize.radiusSm),
                border: value ? null : Border.all(color: border, width: hasError ? 2 : 1.5),
              ),
              child: value ? Icon(LucideIcons.check, size: 20, color: kn.textOnAction) : null,
            ),
            const SizedBox(width: KnSize.space12),
            Expanded(child: CustomBaseTextWidget(label, style: context.knText.body)),
          ],
        ),
      ),
    );
  }
}
