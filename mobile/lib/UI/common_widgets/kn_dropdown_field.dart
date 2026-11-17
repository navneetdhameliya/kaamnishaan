import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';
import 'kn_inline_error.dart';

/// Labelled field that opens a choice sheet (M11 "Your work", M07 trade and country).
/// An empty [value] shows [placeholder]; [errorText] adds the red border and message.
class KnDropdownField extends StatelessWidget {
  const KnDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder,
    this.errorText,
    this.onHearError,
    this.showChevron = true,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final String? placeholder;
  final String? errorText;
  final VoidCallback? onHearError;

  /// A search field (New job's customer) looks like a text field: no arrow.
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    final hasError = errorText != null;
    final empty = value.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomBaseTextWidget(label, style: context.knText.label),
        const SizedBox(height: KnSize.space8),
        CustomInkWell(
          onTap: onTap,
          borderRadius: radius,
          semanticLabel: label,
          child: Ink(
            height: KnSize.tapTechnician,
            padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
            decoration: BoxDecoration(
              color: kn.bgSurface,
              borderRadius: radius,
              border: Border.all(
                color: hasError ? kn.statusDanger : kn.borderStrong,
                width: hasError ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomBaseTextWidget(
                    empty ? (placeholder ?? '') : value,
                    style: context.knText.body,
                    color: empty ? kn.textSecondary : kn.textPrimary,
                    maxLines: 1,
                  ),
                ),
                if (showChevron) Icon(LucideIcons.chevronDown, size: 22, color: kn.textPrimary),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: KnSize.space8),
          KnInlineError(message: errorText!, onHear: onHearError),
        ],
      ],
    );
  }
}
