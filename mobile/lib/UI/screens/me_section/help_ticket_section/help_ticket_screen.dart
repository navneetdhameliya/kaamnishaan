import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../help_section/custom_widgets/help_parts.dart';
import 'help_ticket_controller.dart';

/// M47 A help request and its messages.
class HelpTicketScreen extends GetView<HelpTicketController> {
  const HelpTicketScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        child: Obx(() {
          final t = controller.ticket.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, 0),
                child: Row(
                  children: [
                    const KnBackButton(),
                    const SizedBox(width: KnSize.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(t?.subject ?? LangKeys.helpTitle.tr, style: text.h3, maxLines: 2),
                          if (t != null)
                            Row(
                              children: [
                                CustomBaseTextWidget(t.number, style: text.caption, color: kn.textSecondary),
                                const SizedBox(width: KnSize.space8),
                                TicketStatusPill(status: t.status),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const KnScrollBehavior(),
                  child: !controller.loaded.value || t == null
                      ? ListView(
                          padding: const EdgeInsets.all(KnSize.space16),
                          children: const [
                            CommonShimmer(height: 72, radius: KnSize.radiusLg),
                            SizedBox(height: KnSize.space12),
                            CommonShimmer(height: 96, radius: KnSize.radiusLg),
                          ],
                        )
                      : RefreshIndicator(
                          onRefresh: controller.load,
                          child: ListView(
                            controller: controller.scroll,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(KnSize.space16),
                            children: [
                              for (final m in t.messages ?? const <TicketMessageOutModel>[]) ...[
                                TicketBubble(key: ValueKey('msg-${m.id}'), message: m, when: controller.when(m)),
                                const SizedBox(height: KnSize.space12),
                              ],
                              CustomBaseTextWidget(
                                controller.statusNote,
                                style: text.caption,
                                color: kn.textSecondary,
                                textAlign: TextAlign.center,
                              ),
                              if (!controller.solved) ...[
                                const SizedBox(height: KnSize.space12),
                                KnCustomButton(
                                  key: const ValueKey('help-solve'),
                                  text: LangKeys.helpSolve.tr,
                                  icon: LucideIcons.check,
                                  variant: KnButtonVariant.secondary,
                                  small: true,
                                  loading: controller.solving.value,
                                  onTap: controller.onSolve,
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
              if (t != null) _ReplyBar(controller: controller),
            ],
          );
        }),
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({required this.controller});

  final HelpTicketController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return DecoratedBox(
      decoration: BoxDecoration(color: kn.bgSurface, border: Border(top: BorderSide(color: kn.borderDefault))),
      child: Padding(
        padding: const EdgeInsets.all(KnSize.space12),
        child: Obx(
          () => Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('help-reply'),
                  controller: controller.input,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 4000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  textCapitalization: TextCapitalization.sentences,
                  style: context.knText.bodyLg,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: kn.actionSecondary,
                    hintText: controller.solved ? LangKeys.helpReplyReopen.tr : LangKeys.helpReplyHint.tr,
                    contentPadding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KnSize.radiusFull),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: KnSize.space8),
              CustomInkWell(
                key: const ValueKey('help-send-reply'),
                onTap: controller.canSend ? controller.onSend : null,
                borderRadius: BorderRadius.circular(KnSize.radiusFull),
                semanticLabel: LangKeys.helpSendReply.tr,
                child: Ink(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: controller.canSend ? kn.actionPrimary : kn.actionDisabled,
                    shape: BoxShape.circle,
                  ),
                  child: controller.sending.value
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: CircularProgressIndicator(strokeWidth: 2, color: kn.textOnAction),
                        )
                      : Icon(LucideIcons.send, size: 20, color: kn.textOnAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
