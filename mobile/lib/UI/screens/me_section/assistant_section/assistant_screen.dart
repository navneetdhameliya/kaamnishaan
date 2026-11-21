import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_dictation.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'assistant_controller.dart';
import 'custom_widgets/assistant_parts.dart';

/// M36 Ask KaamNishaan AI (Figma 248:2311; paused 248:2383).
class AssistantScreen extends GetView<AssistantController> {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        child: Obx(
          () => Stack(
            children: [
              Column(
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
                              CustomBaseTextWidget(LangKeys.aiTitle.tr, style: text.h3, maxLines: 1),
                              CustomBaseTextWidget(LangKeys.aiSubtitle.tr, style: text.caption, color: kn.textSecondary),
                            ],
                          ),
                        ),
                        const SizedBox(width: KnSize.space12),
                        const AiMark(size: 44),
                      ],
                    ),
                  ),
                  const SizedBox(height: KnSize.space12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
                    child: Row(
                      children: [
                        for (final c in controller.chips) ...[
                          CustomInkWell(
                            key: ValueKey('ai-chip-${c.key}'),
                            onTap: () => controller.onChip(c),
                            borderRadius: BorderRadius.circular(KnSize.radiusFull),
                            semanticLabel: c.label,
                            child: Ink(
                              padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 7),
                              decoration: BoxDecoration(
                                color: kn.bgSurface,
                                borderRadius: BorderRadius.circular(KnSize.radiusFull),
                                border: Border.all(color: kn.borderDefault),
                              ),
                              child: CustomBaseTextWidget(c.label, style: text.labelSm),
                            ),
                          ),
                          const SizedBox(width: KnSize.space8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: KnSize.space8),
                  Expanded(
                    child: ScrollConfiguration(
                      behavior: const KnScrollBehavior(),
                      child: controller.loading.value
                          ? ListView(
                              padding: const EdgeInsets.all(KnSize.space16),
                              children: const [
                                CommonShimmer(height: 56, radius: KnSize.radiusLg),
                                SizedBox(height: KnSize.space12),
                                CommonShimmer(height: 120, radius: KnSize.radiusLg),
                              ],
                            )
                          : controller.messages.isEmpty
                              ? _Empty(unavailable: !controller.available.value)
                              : ListView.separated(
                                  controller: controller.scroll,
                                  padding: const EdgeInsets.all(KnSize.space16),
                                  itemCount: controller.messages.length + (controller.sending.value ? 1 : 0),
                                  separatorBuilder: (_, _) => const SizedBox(height: KnSize.space12),
                                  itemBuilder: (_, i) {
                                    if (i >= controller.messages.length) {
                                      return const Row(
                                        children: [
                                          AiMark(),
                                          SizedBox(width: KnSize.space8),
                                          SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                        ],
                                      );
                                    }
                                    final m = controller.messages[i];
                                    return m.role == 'user'
                                        ? QuestionBubble(text: m.text)
                                        : AnswerBubble(message: m, controller: controller);
                                  },
                                ),
                    ),
                  ),
                  _InputBar(controller: controller),
                ],
              ),
              if (controller.pausedCard.value)
                Positioned.fill(
                  child: ColoredBox(
                    color: kn.bgCanvas.withValues(alpha: 0.6),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(KnSize.space16),
                        child: PausedCard(controller: controller),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.unavailable});

  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space24, vertical: 48),
      children: [
        const Center(child: AiMark(size: 64)),
        const SizedBox(height: KnSize.space16),
        CustomBaseTextWidget(
          unavailable ? LangKeys.aiUnavailable.tr : LangKeys.aiEmpty.tr,
          style: context.knText.h3,
          textAlign: TextAlign.center,
        ),
        if (!unavailable) ...[
          const SizedBox(height: 4),
          CustomBaseTextWidget(
            LangKeys.aiEmptyBody.tr,
            style: context.knText.body,
            color: kn.textSecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller});

  final AssistantController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return DecoratedBox(
      decoration: BoxDecoration(color: kn.bgSurface, border: Border(top: BorderSide(color: kn.borderDefault))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(KnSize.space12, KnSize.space12, KnSize.space12, KnSize.space12),
        child: Obx(
          () => Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('ai-input'),
                  controller: controller.input,
                  enabled: controller.canAsk,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => controller.onSend(),
                  style: context.knText.bodyLg,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: kn.actionSecondary,
                    hintText: controller.paused.value ? LangKeys.aiPausedHint.tr : LangKeys.aiHint.tr,
                    contentPadding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KnSize.radiusFull),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: KnMicButton(
                      key: const ValueKey('ai-mic'),
                      dictation: controller.dictation,
                      box: controller.input,
                      enabled: controller.canAsk,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: KnSize.space8),
              CustomInkWell(
                key: const ValueKey('ai-send'),
                onTap: controller.canSend ? controller.onSend : null,
                borderRadius: BorderRadius.circular(KnSize.radiusFull),
                semanticLabel: LangKeys.aiSend.tr,
                child: Ink(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: controller.canSend ? kn.actionPrimary : kn.actionDisabled,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.chevronRight, size: 22, color: kn.textOnAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
