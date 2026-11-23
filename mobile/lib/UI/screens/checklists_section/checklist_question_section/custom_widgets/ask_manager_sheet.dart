import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_bottom_sheet.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_dictation.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../checklist_question_controller.dart';

/// M25 "Not sure? Ask your manager": the question, an optional note, then Send (D-142).
Future<void> showAskManagerSheet(ChecklistQuestionController c) => showKnBottomSheet<void>(
      title: LangKeys.askmgrTitle.tr,
      child: Builder(
        builder: (context) {
          final kn = context.kn;
          final text = context.knText;
          return Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomBaseTextWidget(LangKeys.askmgrBody.tr, style: text.caption, color: kn.textSecondary),
                const SizedBox(height: KnSize.space12),
                Container(
                  key: const ValueKey('ask-question'),
                  padding: const EdgeInsets.all(KnSize.space12),
                  decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(LucideIcons.messageCircle, size: 20, color: kn.textSecondary),
                      const SizedBox(width: KnSize.space8),
                      Expanded(child: CustomBaseTextWidget(c.current?.text ?? '', style: text.label)),
                    ],
                  ),
                ),
                const SizedBox(height: KnSize.space16),
                CustomBaseTextWidget(LangKeys.askmgrNote.tr, style: text.label),
                const SizedBox(height: KnSize.space8),
                TextField(
                  key: const ValueKey('ask-note'),
                  controller: c.askNote,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  style: text.body,
                  decoration: InputDecoration(
                    hintText: LangKeys.askmgrNoteHint.tr,
                    counterText: '',
                    filled: true,
                    fillColor: kn.bgSurface,
                    suffixIcon: KnMicButton(key: const ValueKey('ask-note-mic'), dictation: c.dictation, box: c.askNote),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KnSize.radiusMd),
                      borderSide: BorderSide(color: kn.borderStrong),
                    ),
                  ),
                ),
                KnDictationNote(dictation: c.dictation, box: c.askNote),
                const SizedBox(height: KnSize.space16),
                KnCustomButton(
                  key: const ValueKey('ask-send'),
                  text: LangKeys.askmgrSend.tr,
                  icon: LucideIcons.send,
                  loading: c.asking.value,
                  onTap: () async {
                    if (await c.onAskManager()) Get.back<void>();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
