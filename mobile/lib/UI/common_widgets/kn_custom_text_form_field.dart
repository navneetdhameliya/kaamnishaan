import 'package:flutter/material.dart';

import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'kn_inline_error.dart';

/// Labelled text field (M06, M07, M08, M11). [readOnly] shows the greyed style used for the phone number
/// and for a locked login. [hasError] paints the red border without a message (the screen shows its own).
class KnCustomTextFormField extends StatelessWidget {
  const KnCustomTextFormField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.hintText,
    this.errorText,
    this.onHearError,
    this.readOnly = false,
    this.trailing,
    this.onChanged,
    this.textInputAction,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.autofillHints,
    this.onSubmitted,
    this.hasError = false,
    this.fieldKey,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? hintText;
  final String? errorText;
  final VoidCallback? onHearError;
  final bool readOnly;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool hasError;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(KnSize.radiusLg),
          borderSide: BorderSide(color: c, width: w),
        );
    final showRed = hasError || errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomBaseTextWidget(label, style: context.knText.label),
        const SizedBox(height: KnSize.space8),
        TextFormField(
          key: fieldKey,
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          focusNode: focusNode,
          readOnly: readOnly,
          onChanged: onChanged,
          textInputAction: textInputAction,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          obscureText: obscureText,
          obscuringCharacter: '•',
          autocorrect: !obscureText,
          enableSuggestions: !obscureText,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          style: context.knText.body.copyWith(color: readOnly ? kn.textSecondary : kn.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: readOnly ? kn.bgSubtle : kn.bgSurface,
            hintText: hintText,
            contentPadding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: 16),
            suffixIcon: trailing == null
                ? null
                : Padding(padding: const EdgeInsets.only(right: KnSize.space8), child: trailing),
            suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            enabledBorder: border(showRed ? kn.statusDanger : kn.borderStrong, showRed ? 2 : 1),
            focusedBorder: border(showRed ? kn.statusDanger : (readOnly ? kn.borderStrong : kn.focusRing), readOnly ? 1 : 2),
            disabledBorder: border(kn.borderDefault),
            border: border(kn.borderStrong),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: KnSize.space8),
          KnInlineError(message: errorText!, onHear: onHearError),
        ],
      ],
    );
  }
}
