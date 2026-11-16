import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../report_editor_controller.dart';

/// One part of the report: its title, "✦ AI", the text with a microphone, and the empty message.
class PartField extends StatelessWidget {
  const PartField({
    super.key,
    required this.part,
    required this.showAi,
    required this.aiWritten,
    required this.emptyText,
    required this.onMic,
    required this.onAi,
    required this.onHear,
  });

  final ReportPart part;
  final bool showAi;
  final bool aiWritten;
  final String emptyText;
  final VoidCallback onMic;
  final VoidCallback onAi;
  final VoidCallback onHear;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Obx(() {
      final empty = part.empty.value;
      final busy = part.rewriting.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: CustomBaseTextWidget(part.title, style: text.label)),
              if (showAi)
                CustomInkWell(
                  key: ValueKey('part-ai-${part.key}'),
                  onTap: busy ? null : onAi,
                  borderRadius: BorderRadius.circular(KnSize.radiusFull),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.sparkle, size: 12, color: aiWritten ? kn.textSecondary : kn.textLink),
                        const SizedBox(width: 4),
                        CustomBaseTextWidget('AI', style: text.captionStrong, color: aiWritten ? kn.textSecondary : kn.textLink),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: KnSize.space8),
          AnimatedBuilder(
            animation: part.focus,
            builder: (context, _) => Container(
              padding: const EdgeInsets.fromLTRB(KnSize.space12, KnSize.space4, KnSize.space8, KnSize.space4),
              decoration: BoxDecoration(
                color: kn.bgSurface,
                borderRadius: BorderRadius.circular(KnSize.radiusLg),
                border: Border.all(
                  color: empty ? kn.statusDanger : (part.focus.hasFocus ? kn.textSecondary : kn.borderDefault),
                  width: empty || part.focus.hasFocus ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: busy
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: kn.textSecondary),
                                ),
                                const SizedBox(width: KnSize.space8),
                                CustomBaseTextWidget(LangKeys.reportStepWrite.tr, style: text.body, color: kn.textSecondary),
                              ],
                            ),
                          )
                        : TextField(
                            key: ValueKey('part-${part.key}'),
                            controller: part.text,
                            focusNode: part.focus,
                            minLines: 2,
                            maxLines: 10,
                            maxLength: 4000,
                            style: text.body,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                              hintText: LangKeys.editorHint.tr,
                              hintStyle: text.body.copyWith(color: kn.textSecondary),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: CustomInkWell(
                      key: ValueKey('part-mic-${part.key}'),
                      onTap: onMic,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
                        child: Icon(LucideIcons.mic, size: 20, color: kn.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (empty) ...[
            const SizedBox(height: KnSize.space8),
            Row(
              children: [
                Icon(LucideIcons.circleAlert, size: 16, color: kn.statusDanger),
                const SizedBox(width: 6),
                Expanded(child: CustomBaseTextWidget(emptyText, style: text.captionStrong, color: kn.statusDanger)),
                CustomInkWell(
                  key: ValueKey('part-hear-${part.key}'),
                  onTap: onHear,
                  borderRadius: BorderRadius.circular(KnSize.radiusFull),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kn.statusDangerBg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.volume2, size: 14, color: kn.statusDanger),
                        const SizedBox(width: 4),
                        CustomBaseTextWidget(LangKeys.noteHearIt.tr, style: text.labelSm, color: kn.statusDanger),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    });
  }
}
