import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../common/voice_wave.dart';
import 'voice_note_controller.dart';

/// M29 Transcript (Figma 30:1351; "couldn't understand" 74:2271).
class VoiceNoteScreen extends GetView<VoiceNoteController> {
  const VoiceNoteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: Obx(() => _footer()),
      body: SafeArea(
        bottom: false,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: Obx(() {
            final n = controller.note.value;
            return ListView(
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
                          CustomBaseTextWidget(controller.title, style: text.h3),
                          CustomBaseTextWidget(controller.subtitle, style: text.caption, color: kn.textSecondary, maxLines: 1),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: KnSize.space16),
                if (n == null) ...const [
                  CommonShimmer(height: 76, radius: KnSize.radiusLg),
                  SizedBox(height: KnSize.space16),
                  CommonShimmer(height: 220, radius: KnSize.radiusLg),
                ] else ...[
                  if (!controller.typed) ...[_player(context), const SizedBox(height: KnSize.space12)],
                  if (controller.languageLine.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
                          child: Icon(LucideIcons.globe, size: 16, color: kn.textPrimary),
                        ),
                        const SizedBox(width: KnSize.space8),
                        Expanded(child: CustomBaseTextWidget(controller.languageLine, style: text.label)),
                      ],
                    ),
                    const SizedBox(height: KnSize.space12),
                  ],
                  if (n.locked) ...[_lockedBanner(context), const SizedBox(height: KnSize.space12)],
                  _body(context),
                  if (!controller.typed) ...[
                    const SizedBox(height: KnSize.space12),
                    Row(
                      children: [
                        Icon(LucideIcons.lock, size: 16, color: kn.textSecondary),
                        const SizedBox(width: KnSize.space8),
                        Expanded(
                          child: CustomBaseTextWidget(LangKeys.noteAlwaysKept.tr, style: text.caption, color: kn.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _player(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
        boxShadow: KnShadow.sm,
      ),
      child: Row(
        children: [
          CustomInkWell(
            key: const ValueKey('note-play'),
            onTap: controller.onPlayTap,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionPrimary),
              child: Icon(controller.playing ? LucideIcons.pause : LucideIcons.play, size: 24, color: kn.textOnAction),
            ),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                VoiceWave(
                  seed: controller.noteId,
                  progress: controller.progress,
                  color: kn.textSecondary.withValues(alpha: 0.6),
                  playedColor: kn.textPrimary,
                  height: 24,
                  barWidth: 2.5,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CustomBaseTextWidget(TimeUtils.minSec(controller.position), style: text.caption, color: kn.textSecondary),
                    CustomBaseTextWidget(TimeUtils.minSec(controller.length), style: text.caption, color: kn.textSecondary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child, Color? color, Color? border}) {
    final kn = context.kn;
    return Container(
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(
        color: color ?? kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: border ?? kn.borderDefault),
        boxShadow: color == null ? KnShadow.sm : null,
      ),
      child: child,
    );
  }

  Widget _body(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    if (controller.editing.value) {
      return _card(
        context,
        child: TextField(
          key: const ValueKey('note-edit-field'),
          controller: controller.textController,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          maxLength: 8000,
          style: text.bodyLg,
          decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
        ),
      );
    }
    if (controller.writing) {
      return _card(
        context,
        child: Row(
          children: [
            SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kn.textSecondary)),
            const SizedBox(width: KnSize.space12),
            Expanded(child: CustomBaseTextWidget(LangKeys.noteWriting.tr, style: text.body, color: kn.textSecondary)),
          ],
        ),
      );
    }
    if (controller.failed) {
      return _card(
        context,
        color: kn.statusDangerBg,
        border: kn.statusDanger,
        child: Row(
          children: [
            Icon(LucideIcons.circleAlert, color: kn.statusDanger),
            const SizedBox(width: KnSize.space12),
            Expanded(child: CustomBaseTextWidget(LangKeys.noteFailed.tr, style: text.label)),
          ],
        ),
      );
    }
    if (controller.unclear) return _unclear(context);
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomBaseTextWidget(
                  controller.typed ? LangKeys.noteWhatYouWrote.tr : LangKeys.noteWhatYouSaid.tr,
                  style: text.captionStrong,
                  color: kn.textSecondary,
                ),
              ),
              if (controller.canEdit)
                CustomInkWell(
                  key: const ValueKey('note-edit'),
                  onTap: controller.onEditTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(LucideIcons.pencil, size: 18, color: kn.textSecondary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: KnSize.space8),
          CustomBaseTextWidget(controller.reportText, style: text.bodyLg.copyWith(fontSize: 18, height: 28 / 18)),
        ],
      ),
    );
  }

  Widget _unclear(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    Widget tip(String s) => Padding(
          padding: const EdgeInsets.only(top: KnSize.space8),
          child: Row(
            children: [
              Icon(LucideIcons.check, size: 16, color: kn.statusSuccess),
              const SizedBox(width: KnSize.space8),
              Expanded(child: CustomBaseTextWidget(s, style: text.caption)),
            ],
          ),
        );
    return _card(
      context,
      color: kn.statusDangerBg,
      border: kn.statusDanger,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: kn.statusDanger),
                child: Icon(LucideIcons.circleAlert, size: 20, color: kn.textOnAction),
              ),
              const SizedBox(width: KnSize.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomBaseTextWidget(LangKeys.noteUnclearTitle.tr, style: text.label),
                    const SizedBox(height: 2),
                    CustomBaseTextWidget(LangKeys.noteUnclearBody.tr, style: text.body),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KnSize.space4),
          tip(LangKeys.noteUnclearTip1.tr),
          tip(LangKeys.noteUnclearTip2.tr),
          const SizedBox(height: KnSize.space12),
          CustomInkWell(
            key: const ValueKey('note-hear-it'),
            onTap: controller.onPlayTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.volume2, size: 16, color: kn.statusDanger),
                  const SizedBox(width: 6),
                  CustomBaseTextWidget(LangKeys.noteHearIt.tr, style: text.labelSm, color: kn.statusDanger),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockedBanner(BuildContext context) {
    final kn = context.kn;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
      child: Row(
        children: [
          Icon(LucideIcons.lock, size: 18, color: kn.textPrimary),
          const SizedBox(width: KnSize.space8),
          Expanded(child: CustomBaseTextWidget(LangKeys.noteLocked.tr, style: context.knText.caption)),
        ],
      ),
    );
  }

  Widget _footer() {
    final n = controller.note.value;
    if (n == null || n.locked) return const SizedBox.shrink();
    Widget pair(Widget a, Widget b) => KnScreenFooter(
          children: [
            Row(
              children: [
                Expanded(child: a),
                const SizedBox(width: KnSize.space12),
                Expanded(child: b),
              ],
            ),
          ],
        );
    if (controller.failed) {
      return KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('note-retry'),
            text: LangKeys.noteTryAgain.tr,
            icon: LucideIcons.rotateCw,
            loading: controller.saving.value,
            onTap: controller.onRetryTap,
          ),
        ],
      );
    }
    if (controller.unclear && !controller.editing.value) {
      return pair(
        KnCustomButton(
          key: const ValueKey('note-type-instead'),
          text: LangKeys.noteTypeInstead.tr,
          icon: LucideIcons.pencil,
          variant: KnButtonVariant.secondary,
          onTap: controller.onTypeInsteadTap,
        ),
        KnCustomButton(
          key: const ValueKey('note-speak-again'),
          text: LangKeys.noteSpeakAgain.tr,
          icon: LucideIcons.mic,
          onTap: controller.onSpeakTap,
        ),
      );
    }
    final save = KnCustomButton(
      key: const ValueKey('note-save'),
      text: LangKeys.commonSave.tr,
      icon: LucideIcons.check,
      loading: controller.saving.value,
      onTap: controller.onSaveTap,
    );
    if (controller.typed) return KnScreenFooter(children: [save]);
    return KnScreenFooter(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: KnCustomButton(
                key: const ValueKey('note-speak-change'),
                text: LangKeys.noteSpeakChange.tr,
                icon: LucideIcons.mic,
                variant: KnButtonVariant.secondary,
                onTap: controller.onSpeakTap,
              ),
            ),
            const SizedBox(width: KnSize.space12),
            Expanded(flex: 2, child: save),
          ],
        ),
      ],
    );
  }
}
