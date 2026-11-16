import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// The dark top of M12 and M13: decorative ring, photo, greeting, name and the bell.
/// [child] sits under the greeting (stats, this week, "Set up your team").
/// Heights follow the design measured below a 32 px status bar; [top] is the real status bar.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.top,
    required this.height,
    required this.greeting,
    required this.name,
    required this.initials,
    required this.onBell,
    this.avatarUrl,
    this.unread = false,
    this.ringLeft = 220,
    this.ringTop = -102,
    this.child,
  });

  final double top;
  final double height;
  final String greeting;
  final String name;
  final String initials;
  final String? avatarUrl;
  final bool unread;
  final VoidCallback onBell;
  final double ringLeft;
  final double ringTop;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    return Container(
      height: top + height,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: KnPrimitive.mocha900,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: ringLeft,
            top: top + ringTop,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: KnPrimitive.mocha700.withValues(alpha: 0.6), width: 28),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(KnSize.space16, top + 12, KnSize.space16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      KnInitialsAvatar(initials: initials, url: avatarUrl, size: 44),
                      const SizedBox(width: KnSize.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CustomBaseTextWidget(greeting, style: text.body, color: KnPrimitive.cream400, maxLines: 1),
                            CustomBaseTextWidget(name, style: text.h2, color: KnPrimitive.cream50, maxLines: 1),
                          ],
                        ),
                      ),
                      const SizedBox(width: KnSize.space12),
                      _bell(),
                    ],
                  ),
                ),
                ?child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bell() => CustomInkWell(
        key: const ValueKey('bell'),
        onTap: onBell,
        borderRadius: BorderRadius.circular(22),
        semanticLabel: LangKeys.commonNotifications.tr,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: KnPrimitive.cream100.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(LucideIcons.bell, size: 22, color: KnPrimitive.cream50),
              ),
              if (unread)
                Positioned(
                  left: 29,
                  top: 6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: KnPrimitive.red600,
                      shape: BoxShape.circle,
                      border: Border.all(color: KnPrimitive.mocha900, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
