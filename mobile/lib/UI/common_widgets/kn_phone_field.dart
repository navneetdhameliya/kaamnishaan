import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// Country button + phone number box (M05). The number is typed with [KnNumberKeypad].
class KnPhoneField extends StatelessWidget {
  const KnPhoneField({
    super.key,
    required this.flag,
    required this.dialCode,
    required this.number,
    required this.onCountryTap,
    this.hasError = false,
  });

  final String flag;
  final String dialCode;
  final String number;
  final VoidCallback onCountryTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    return Row(
      children: [
        CustomInkWell(
          key: const ValueKey('country-button'),
          onTap: onCountryTap,
          borderRadius: radius,
          semanticLabel: dialCode,
          child: Ink(
            height: KnSize.tapTechnician,
            padding: const EdgeInsets.symmetric(horizontal: KnSize.space12),
            decoration: BoxDecoration(
              color: kn.bgSurface,
              borderRadius: radius,
              border: Border.all(color: kn.borderDefault),
            ),
            child: Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                CustomBaseTextWidget(dialCode, style: context.knText.label),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronDown, size: 18, color: kn.textSecondary),
              ],
            ),
          ),
        ),
        const SizedBox(width: KnSize.space8),
        Expanded(
          child: Container(
            height: KnSize.tapTechnician,
            padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
            decoration: BoxDecoration(
              color: kn.bgSurface,
              borderRadius: radius,
              border: Border.all(color: hasError ? kn.statusDanger : kn.focusRing, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomBaseTextWidget(
                    number,
                    key: const ValueKey('phone-number'),
                    style: context.knText.bodyLg,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                  ),
                ),
                Icon(LucideIcons.phone, size: 20, color: kn.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
