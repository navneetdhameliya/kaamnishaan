import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/mic_off_view.dart';
import 'custom_widgets/recording_view.dart';
import 'custom_widgets/typed_note_sheet.dart';
import 'voice_record_controller.dart';

/// M27 Voice note (Figma 28:1292 recording, 28:1391 microphone off).
class VoiceRecordScreen extends GetView<VoiceRecordController> {
  const VoiceRecordScreen({super.key});

  Future<void> _typeInstead() async {
    final saved = await showTypedNoteSheet(controller);
    if (saved == true) controller.afterTyped();
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        final denied = controller.phase.value == RecordPhase.denied;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) controller.onBackTap();
          },
          child: denied ? _micOff(context) : _recording(context),
        );
      });

  Widget _recording(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: KnPrimitive.mocha900,
        bottomNavigationBar: KnScreenFooter(
          children: [
            Row(
              children: [
                Obx(
                  () => KnCustomButton(
                    key: const ValueKey('voice-pause'),
                    text: controller.isPaused ? LangKeys.voiceResume.tr : LangKeys.voicePause.tr,
                    variant: KnButtonVariant.secondary,
                    enabled: controller.isRecording || controller.isPaused,
                    onTap: controller.onPauseTap,
                  ),
                ),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  child: Obx(
                    () => KnCustomButton(
                      key: const ValueKey('voice-stop-save'),
                      text: LangKeys.voiceStopSave.tr,
                      icon: LucideIcons.check,
                      loading: controller.phase.value == RecordPhase.saving,
                      enabled: controller.isRecording || controller.isPaused,
                      onTap: controller.onStopSaveTap,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topBar(context),
                const SizedBox(height: KnSize.space16),
                const VoicePromptCard(),
                Expanded(child: RecordingView(controller: controller)),
                const SizedBox(height: KnSize.space8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final text = context.knText;
    return Row(
      children: [
        DarkRoundButton(key: const ValueKey('voice-back'), icon: LucideIcons.chevronLeft, onTap: controller.onBackTap),
        const SizedBox(width: KnSize.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBaseTextWidget(LangKeys.voiceTitle.tr, style: text.h3, color: KnPrimitive.cream50),
              CustomBaseTextWidget(controller.args.customer, style: text.caption, color: KnPrimitive.cream400, maxLines: 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _micOff(BuildContext context) {
    final kn = context.kn;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('voice-open-settings'),
            text: LangKeys.voiceOpenSettings.tr,
            icon: LucideIcons.slidersHorizontal,
            onTap: controller.onOpenSettingsTap,
          ),
          KnCustomButton(
            key: const ValueKey('voice-type-instead'),
            text: LangKeys.voiceTypeInstead.tr,
            icon: LucideIcons.pencil,
            variant: KnButtonVariant.ghost,
            onTap: _typeInstead,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: MicOffView(onBackTap: controller.onBackTap),
      ),
    );
  }
}

/// The round back button on the dark recorder.
class DarkRoundButton extends StatelessWidget {
  const DarkRoundButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: KnPrimitive.cream100.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 44, child: Icon(icon, size: 22, color: KnPrimitive.cream100)),
        ),
      );
}
