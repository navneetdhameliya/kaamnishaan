import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../common_widgets/kn_bottom_sheet.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../voice_record_controller.dart';

/// "Type notes instead" (microphone off): returns true when a note was saved.
Future<bool?> showTypedNoteSheet(VoiceRecordController controller) => showKnBottomSheet<bool>(
      title: LangKeys.voiceTypeTitle.tr,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('typed-note-field'),
              controller: controller.typedController,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              maxLength: 4000,
              style: context.knText.body,
              decoration: InputDecoration(
                hintText: LangKeys.voicePromptBody.tr,
                filled: true,
                fillColor: context.kn.bgSurface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusLg)),
              ),
            ),
            const SizedBox(height: KnSize.space12),
            Obx(
              () => KnCustomButton(
                key: const ValueKey('typed-note-save'),
                text: LangKeys.voiceTypeSave.tr,
                loading: controller.savingTyped.value,
                onTap: () async {
                  if (await controller.onSaveTypedTap()) Get.back<bool>(result: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
