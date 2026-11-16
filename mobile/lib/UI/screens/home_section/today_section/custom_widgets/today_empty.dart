import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// M12 "No jobs today" with Refresh, and "Expecting a job? Call Priya, your manager." (Figma 19:973).
class TodayEmpty extends StatelessWidget {
  const TodayEmpty({super.key, required this.onRefresh, this.managerName, this.onCallManager});

  final VoidCallback onRefresh;
  final String? managerName;
  final VoidCallback? onCallManager;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('today-empty'),
          padding: const EdgeInsets.symmetric(horizontal: KnSize.space24, vertical: KnSize.space32),
          decoration: BoxDecoration(
            color: kn.bgSurface,
            borderRadius: BorderRadius.circular(KnSize.radiusLg),
            boxShadow: KnShadow.md,
          ),
          child: Column(
            children: [
              SizedBox(
                width: 120,
                height: 104,
                child: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(color: kn.bgSubtle, shape: BoxShape.circle),
                        child: Icon(LucideIcons.briefcase, size: 44, color: kn.textSecondary),
                      ),
                    ),
                    Positioned(
                      left: 84,
                      top: 64,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: KnPrimitive.sage100,
                          shape: BoxShape.circle,
                          border: Border.all(color: kn.bgSurface, width: 3),
                        ),
                        child: const Icon(LucideIcons.check, size: 18, color: KnPrimitive.sage700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KnSize.space12),
              CustomBaseTextWidget(LangKeys.todayEmptyTitle.tr, style: text.h2, textAlign: TextAlign.center),
              const SizedBox(height: KnSize.space12),
              CustomBaseTextWidget(
                LangKeys.todayEmptyBody.tr,
                style: text.body,
                color: kn.textSecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KnSize.space12),
              IntrinsicWidth(
                child: KnCustomButton(
                  key: const ValueKey('today-refresh'),
                  text: LangKeys.commonRefresh.tr,
                  icon: LucideIcons.rotateCw,
                  variant: KnButtonVariant.secondary,
                  onTap: onRefresh,
                ),
              ),
            ],
          ),
        ),
        if (managerName != null) ...[
          const SizedBox(height: KnSize.space16),
          CustomInkWell(
            key: const ValueKey('call-manager'),
            onTap: onCallManager,
            borderRadius: BorderRadius.circular(KnSize.radiusLg),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: KnSize.space12),
              decoration: BoxDecoration(color: KnPrimitive.sage100, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: KnPrimitive.cream50, shape: BoxShape.circle),
                    child: const Icon(LucideIcons.phone, size: 18, color: KnPrimitive.sage700),
                  ),
                  const SizedBox(width: KnSize.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBaseTextWidget(LangKeys.todayExpecting.tr, style: text.label, color: KnPrimitive.mocha950),
                        CustomBaseTextWidget(
                          LangKeys.todayCallManager.trParams({'name': managerName!}),
                          style: text.caption,
                          color: KnPrimitive.taupe550,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
