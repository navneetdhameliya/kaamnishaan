import 'package:flutter/material.dart';

import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';

/// A white box to type in: a reply, a private note, a question. [minLines] 1 makes it one line that grows.
class KnTextBox extends StatelessWidget {
  const KnTextBox({
    super.key,
    required this.controller,
    required this.hint,
    this.fieldKey,
    this.minLines = 3,
    this.maxLines = 6,
    this.maxLength = 1000,
  });

  final TextEditingController controller;
  final String hint;
  final Key? fieldKey;
  final int minLines;
  final int maxLines;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(KnSize.radiusMd),
      borderSide: BorderSide(color: kn.textPrimary, width: 1.5),
    );
    return TextField(
      key: fieldKey,
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
      textCapitalization: TextCapitalization.sentences,
      style: context.knText.bodyLg,
      decoration: InputDecoration(
        filled: true,
        fillColor: kn.bgSurface,
        hintText: hint,
        border: border,
        enabledBorder: border.copyWith(borderSide: BorderSide(color: kn.borderStrong)),
        focusedBorder: border,
        contentPadding: const EdgeInsets.all(KnSize.space16),
      ),
    );
  }
}
