import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/help_parts.dart';
import 'help_controller.dart';

/// M47 Help (no Figma frame yet: follows M42 Messages and the A28 ticket list).
class HelpScreen extends GetView<HelpController> {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: Obx(
              () => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space24),
                children: [
                  Row(
                    children: [
                      const KnBackButton(),
                      const SizedBox(width: KnSize.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomBaseTextWidget(LangKeys.helpTitle.tr, style: text.h3),
                            CustomBaseTextWidget(LangKeys.helpSubtitle.tr, style: text.caption, color: kn.textSecondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space16),
                  KnCustomButton(
                    key: const ValueKey('help-new'),
                    text: LangKeys.helpNew.tr,
                    icon: LucideIcons.plus,
                    onTap: controller.onNew,
                  ),
                  const SizedBox(height: KnSize.space24),
                  if (!controller.loaded.value) ...const [
                    CommonShimmer(height: 84, radius: KnSize.radiusLg),
                    SizedBox(height: KnSize.space12),
                    CommonShimmer(height: 84, radius: KnSize.radiusLg),
                  ] else if (controller.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 32),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
                            child: Icon(LucideIcons.messageCircle, size: 36, color: kn.textSecondary),
                          ),
                          const SizedBox(height: KnSize.space16),
                          CustomBaseTextWidget(LangKeys.helpEmpty.tr, style: text.h3, textAlign: TextAlign.center),
                          const SizedBox(height: KnSize.space4),
                          CustomBaseTextWidget(
                            LangKeys.helpEmptyBody.tr,
                            style: text.body,
                            color: kn.textSecondary,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else ...[
                    CustomBaseTextWidget(LangKeys.helpYourRequests.tr, style: text.labelSm, color: kn.textSecondary),
                    const SizedBox(height: KnSize.space8),
                    for (final t in controller.items) ...[
                      TicketCard(
                        key: ValueKey('ticket-${t.id}'),
                        ticket: t,
                        when: controller.when(t),
                        onTap: () => controller.onOpen(t),
                      ),
                      const SizedBox(height: KnSize.space12),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
