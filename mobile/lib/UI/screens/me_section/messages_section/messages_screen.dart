import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/message_card.dart';
import 'messages_controller.dart';

/// M42 Messages (Figma 33:1716).
class MessagesScreen extends GetView<MessagesController> {
  const MessagesScreen({super.key});

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
                            CustomBaseTextWidget(LangKeys.messagesTitle.tr, style: text.h3),
                            CustomBaseTextWidget(controller.subtitle, style: text.caption, color: kn.textSecondary),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space16),
                  if (!controller.loaded.value) ...const [
                    CommonShimmer(height: 92, radius: KnSize.radiusLg),
                    SizedBox(height: KnSize.space12),
                    CommonShimmer(height: 92, radius: KnSize.radiusLg),
                  ] else if (controller.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 64),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
                            child: Icon(LucideIcons.bell, size: 36, color: kn.textSecondary),
                          ),
                          const SizedBox(height: KnSize.space16),
                          CustomBaseTextWidget(LangKeys.messagesEmpty.tr, style: text.h3, textAlign: TextAlign.center),
                          const SizedBox(height: KnSize.space4),
                          CustomBaseTextWidget(
                            LangKeys.messagesEmptyBody.tr,
                            style: text.body,
                            color: kn.textSecondary,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    for (final (day, list) in controller.groups) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: KnSize.space8),
                        child: CustomBaseTextWidget(day, style: text.labelSm, color: kn.textSecondary),
                      ),
                      for (final n in list) ...[
                        MessageCard(
                          key: ValueKey('message-${n.id}'),
                          title: controller.title(n),
                          body: controller.body(n),
                          when: controller.when(n),
                          coverUrl: n.coverUrl,
                          tone: controller.tone(n),
                          fresh: controller.fresh.contains(n.id),
                          onTap: () => controller.onOpen(n),
                        ),
                        const SizedBox(height: KnSize.space12),
                      ],
                      const SizedBox(height: KnSize.space4),
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
