import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';

/// "Open", "Support replied" or "Solved" for a help request.
class TicketStatusPill extends StatelessWidget {
  const TicketStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final (bg, fg, label) = switch (status) {
      'waiting' => (kn.statusWarningBg, kn.statusWarning, LangKeys.helpStatusWaiting.tr),
      'solved' => (kn.statusSuccessBg, kn.statusSuccess, LangKeys.helpStatusSolved.tr),
      _ => (kn.bgSubtle, kn.textSecondary, LangKeys.helpStatusOpen.tr),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
      child: CustomBaseTextWidget(label, style: context.knText.captionStrong, color: fg),
    );
  }
}

/// One help request in the list.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket, required this.when, required this.onTap});

  final TicketOutModel ticket;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return CustomInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(KnSize.radiusLg),
      semanticLabel: ticket.subject,
      child: Ink(
        padding: const EdgeInsets.all(KnSize.space16),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: BorderRadius.circular(KnSize.radiusLg),
          border: Border.all(color: ticket.status == 'waiting' ? kn.statusWarning : kn.borderDefault),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomBaseTextWidget(ticket.number, style: text.caption, color: kn.textSecondary),
                const SizedBox(width: KnSize.space8),
                TicketStatusPill(status: ticket.status),
                const Spacer(),
                CustomBaseTextWidget(when, style: text.caption, color: kn.textSecondary),
              ],
            ),
            const SizedBox(height: KnSize.space8),
            CustomBaseTextWidget(ticket.subject, style: text.label, maxLines: 2),
          ],
        ),
      ),
    );
  }
}

/// A message in a help request: the person's own on the right, support's on the left.
class TicketBubble extends StatelessWidget {
  const TicketBubble({super.key, required this.message, required this.when});

  final TicketMessageOutModel message;
  final String when;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final mine = !message.fromSupport;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          padding: const EdgeInsets.all(KnSize.space12),
          decoration: BoxDecoration(
            color: mine ? kn.actionSecondary : kn.bgSurface,
            borderRadius: BorderRadius.circular(KnSize.radiusLg),
            border: mine ? null : Border.all(color: kn.borderDefault),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBaseTextWidget(
                '${mine ? LangKeys.helpYou.tr : LangKeys.helpSupport.tr} · $when',
                style: text.caption,
                color: kn.textSecondary,
              ),
              const SizedBox(height: KnSize.space4),
              CustomBaseTextWidget(message.body, style: text.body),
            ],
          ),
        ),
      ),
    );
  }
}
