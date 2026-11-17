import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/wait_item_card.dart';
import 'waiting_to_send_controller.dart';

/// M43 Waiting to send (Figma 34:1649) and Everything sent (34:1729).
class WaitingToSendScreen extends GetView<WaitingToSendController> {
  const WaitingToSendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Obx(() {
      final done = controller.allSent;
      return Scaffold(
        backgroundColor: kn.bgCanvas,
        bottomNavigationBar: KnScreenFooter(
          children: [
            if (done)
              KnCustomButton(
                key: const ValueKey('pending-back-today'),
                text: LangKeys.pendingBackToday.tr,
                icon: LucideIcons.house,
                onTap: controller.onBackTodayTap,
              )
            else
              KnCustomButton(
                key: const ValueKey('pending-send-all'),
                text: LangKeys.pendingSendAll.tr,
                icon: LucideIcons.cloudUpload,
                loading: controller.sending.value,
                onTap: controller.onSendAllTap,
              ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: ListView(
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
                          CustomBaseTextWidget(LangKeys.meWaiting.tr, style: text.h3),
                          CustomBaseTextWidget(LangKeys.pendingSubtitle.tr, style: text.caption, color: kn.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KnSize.space16),
                if (done) AllSentView(controller: controller) else ..._waiting(context),
              ],
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _waiting(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return [
      Container(
        padding: const EdgeInsets.all(KnSize.space12),
        decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kn.bgSurface),
              child: Icon(LucideIcons.cloudOff, size: 20, color: kn.textPrimary),
            ),
            const SizedBox(width: KnSize.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomBaseTextWidget(controller.summary, style: text.label),
                  const SizedBox(height: KnSize.space8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(KnSize.radiusFull),
                    child: LinearProgressIndicator(
                      value: controller.progress.clamp(0.04, 1.0),
                      minHeight: 6,
                      color: kn.textPrimary,
                      backgroundColor: kn.bgSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: KnSize.space12),
      for (final item in controller.items) ...[
        WaitItemCard(
          key: ValueKey('wait-${item.id}'),
          item: item,
          onTryAgain: () => controller.onTryAgainTap(item),
        ),
        const SizedBox(height: KnSize.space12),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.rotateCw, size: 14, color: kn.textSecondary),
          ),
          const SizedBox(width: KnSize.space8),
          Expanded(child: CustomBaseTextWidget(LangKeys.pendingAuto.tr, style: text.caption, color: kn.textSecondary)),
        ],
      ),
    ];
  }
}
