import 'package:flutter/material.dart';

import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';

enum KnOtpState { normal, error, expired }

/// Four code boxes (M05 SMS code). The next empty box shows the cursor.
class KnOtpBoxes extends StatelessWidget {
  const KnOtpBoxes({super.key, required this.code, this.length = 4, this.state = KnOtpState.normal});

  final String code;
  final int length;
  final KnOtpState state;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Row(
      children: [
        for (var i = 0; i < length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 76,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: state == KnOtpState.error ? kn.statusDangerBg : kn.bgSurface,
                borderRadius: BorderRadius.circular(KnSize.radiusMd),
                border: Border.all(
                  color: switch (state) {
                    KnOtpState.error => kn.statusDanger,
                    _ when state == KnOtpState.normal && i == code.length => kn.focusRing,
                    _ => kn.borderDefault,
                  },
                  width: state == KnOtpState.error || (state == KnOtpState.normal && i == code.length) ? 2 : 1,
                ),
              ),
              child: i < code.length
                  ? Text(
                      code[i],
                      style: context.knText.h2.copyWith(
                        fontSize: 28,
                        color: state == KnOtpState.expired ? kn.borderStrong : kn.textPrimary,
                      ),
                    )
                  : (state == KnOtpState.normal && i == code.length)
                      ? Container(width: 2, height: 28, color: kn.textPrimary)
                      : null,
            ),
          ),
        ],
      ],
    );
  }
}
