import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/services/photo_queue_service.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../waiting_to_send_controller.dart';

/// One thing waiting: its picture or icon, what and where, and Waiting / Sending / Not sent.
class WaitItemCard extends StatelessWidget {
  const WaitItemCard({super.key, required this.item, required this.onTryAgain});

  final WaitItem item;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final failed = item.state == PendingState.failed;
    final (Color bg, Color fg, IconData icon, String label) = switch (item.state) {
      PendingState.failed => (kn.statusDangerBg, kn.statusDanger, LucideIcons.circleAlert, LangKeys.pendingNotSent.tr),
      PendingState.sending => (kn.statusInfoBg, kn.statusInfo, LucideIcons.rotateCw, LangKeys.pendingSending.tr),
      PendingState.waiting => (kn.actionSecondary, kn.textPrimary, LucideIcons.clock, LangKeys.pendingWaiting.tr),
    };
    final path = item.path;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: failed ? kn.statusDanger : kn.borderDefault, width: failed ? 1.5 : 1),
        boxShadow: KnShadow.sm,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(KnSize.radiusMd),
            child: SizedBox.square(
              dimension: 60,
              child: path != null && File(path).existsSync()
                  ? Image.file(File(path), fit: BoxFit.cover, cacheWidth: 180)
                  : ColoredBox(
                      color: kn.actionSecondary,
                      child: Icon(
                        switch (item.kind) {
                          WaitKind.voice => LucideIcons.mic,
                          WaitKind.typed => LucideIcons.pencil,
                          WaitKind.answers => LucideIcons.listChecks,
                          WaitKind.photo => LucideIcons.image,
                        },
                        size: 24,
                        color: kn.textPrimary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(item.title, style: text.label, maxLines: 1),
                if (item.subtitle.isNotEmpty)
                  CustomBaseTextWidget(item.subtitle, style: text.caption, color: kn.textSecondary, maxLines: 1),
                const SizedBox(height: KnSize.space8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 14, color: fg),
                          const SizedBox(width: 6),
                          CustomBaseTextWidget(label, style: text.labelSm, color: fg),
                        ],
                      ),
                    ),
                    if (failed) ...[
                      const Spacer(),
                      KnCustomButton(
                        key: ValueKey('wait-retry-${item.id}'),
                        text: LangKeys.pendingTryAgain.tr,
                        variant: KnButtonVariant.secondary,
                        small: true,
                        onTap: onTryAgain,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Everything is sent".
class AllSentView extends StatelessWidget {
  const AllSentView({super.key, required this.controller});

  final WaitingToSendController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: KnSize.space16),
        Center(
          child: SizedBox.square(
            dimension: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusSuccessBg),
                ),
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusSuccess),
                  child: const Icon(LucideIcons.cloud, size: 44, color: KnPrimitive.cream50),
                ),
                Positioned(
                  right: 18,
                  bottom: 22,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: kn.bgSurface, boxShadow: KnShadow.sm),
                    child: Icon(LucideIcons.check, size: 20, color: kn.statusSuccess),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KnSize.space24),
        CustomBaseTextWidget(LangKeys.pendingAllSent.tr, style: text.h1, textAlign: TextAlign.center),
        const SizedBox(height: KnSize.space8),
        CustomBaseTextWidget(
          LangKeys.pendingAllSentBody.tr,
          style: text.bodyLg,
          color: kn.textSecondary,
          textAlign: TextAlign.center,
        ),
        if (controller.sentCount > 0) ...[
          const SizedBox(height: KnSize.space24),
          Container(
            padding: const EdgeInsets.all(KnSize.space16),
            decoration: BoxDecoration(
              color: kn.bgSurface,
              borderRadius: BorderRadius.circular(KnSize.radiusLg),
              border: Border.all(color: kn.borderDefault),
              boxShadow: KnShadow.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                      child: Icon(LucideIcons.images, size: 22, color: kn.textPrimary),
                    ),
                    const SizedBox(width: KnSize.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(
                            LangKeys.pendingSentItems.trParams({'n': '${controller.sentCount}'}),
                            style: text.label,
                          ),
                          CustomBaseTextWidget(controller.sentDetail, style: text.caption, color: kn.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KnSize.space12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: kn.statusSuccessBg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.check, size: 14, color: kn.statusSuccess),
                      const SizedBox(width: 6),
                      CustomBaseTextWidget(controller.sentAt, style: text.labelSm, color: kn.statusSuccess),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
