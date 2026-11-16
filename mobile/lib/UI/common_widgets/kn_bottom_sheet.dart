import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../infrastructure/lang/lang_keys.g.dart';
import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';

/// Bottom sheet with a handle, a title and a round close button (M05 "Choose country").
Future<T?> showKnBottomSheet<T>({required String title, required Widget child}) {
  return Get.bottomSheet<T>(
    _KnSheet(title: title, child: child),
    isScrollControlled: true,
    ignoreSafeArea: false,
  );
}

class _KnSheet extends StatelessWidget {
  const _KnSheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      child: Material(
        color: kn.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(KnSize.radiusXl + 4)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: kn.borderStrong, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: KnSize.space12),
                Row(
                  children: [
                    Expanded(child: CustomBaseTextWidget(title, style: context.knText.h3)),
                    CustomInkWell(
                      onTap: Get.back,
                      borderRadius: BorderRadius.circular(22),
                      semanticLabel: LangKeys.commonClose.tr,
                      child: Ink(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
                        child: Icon(LucideIcons.x, size: 22, color: kn.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KnSize.space12),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
