import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/shared/text_utils.dart';
import '../../../../common_widgets/kn_bottom_sheet.dart';
import '../../../../common_widgets/kn_checkbox_tile.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../common_widgets/kn_toast.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../report_review_controller.dart';

/// M33 "Ask for changes" (Figma 47:1281; reason needed 77:2182). Returns true when it was sent.
Future<bool?> showChangesSheet(ReportReviewController c) => showKnBottomSheet<bool>(
      title: LangKeys.changesTitle.trParams({'name': c.techFirst}),
      child: Builder(
        builder: (context) {
          final kn = context.kn;
          final text = context.knText;
          return Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    KnInitialsAvatar(
                      initials: TextUtils.initials(c.techName),
                      url: c.report.value?.job.technician?.avatarUrl,
                      size: 36,
                      borderWidth: 0,
                    ),
                    const SizedBox(width: KnSize.space12),
                    Expanded(
                      child: CustomBaseTextWidget(LangKeys.changesBody.tr, style: text.caption, color: kn.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: KnSize.space16),
                CustomBaseTextWidget(LangKeys.changesWhat.tr, style: text.label),
                const SizedBox(height: KnSize.space8),
                for (final (i, o) in c.options.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: KnSize.space4),
                    child: KnCheckboxTile(
                      key: ValueKey('change-option-$i'),
                      value: o.checked.value,
                      label: o.label,
                      hasError: c.changesError.value != null && !c.canSendChanges,
                      onChanged: (_) => c.onOptionTap(o),
                    ),
                  ),
                const SizedBox(height: KnSize.space12),
                CustomBaseTextWidget(LangKeys.changesNote.trParams({'name': c.techFirst}), style: text.label),
                const SizedBox(height: KnSize.space8),
                TextField(
                  key: const ValueKey('change-note'),
                  controller: c.note,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                  style: text.body,
                  onChanged: (_) => c.changesError.value = null,
                  decoration: InputDecoration(
                    hintText: LangKeys.changesNoteHint.tr,
                    counterText: '',
                    filled: true,
                    fillColor: kn.bgSurface,
                    suffixIcon: IconButton(
                      icon: Icon(LucideIcons.mic, size: 20, color: kn.textSecondary),
                      onPressed: () => KnToast.info(LangKeys.editorSpeakHint.tr),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(KnSize.radiusMd),
                      borderSide: BorderSide(color: c.changesError.value != null ? kn.statusDanger : kn.borderStrong),
                    ),
                  ),
                ),
                if (c.changesError.value != null) ...[
                  const SizedBox(height: KnSize.space8),
                  Row(
                    children: [
                      Icon(LucideIcons.circleAlert, size: 16, color: kn.statusDanger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: CustomBaseTextWidget(c.changesError.value!, style: text.captionStrong, color: kn.statusDanger),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: KnSize.space16),
                KnCustomButton(
                  key: const ValueKey('change-send'),
                  text: LangKeys.changesSend.trParams({'name': c.techFirst}),
                  loading: c.sending.value,
                  onTap: () async {
                    if (await c.onSendChangesTap()) Get.back<bool>(result: true);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
