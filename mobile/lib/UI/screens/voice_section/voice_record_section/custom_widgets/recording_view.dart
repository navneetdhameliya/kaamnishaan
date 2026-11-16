import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/commons/constants/image_constants.dart';
import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../../common/voice_texts.dart';
import '../../common/voice_wave.dart';
import '../voice_record_controller.dart';

/// "Tell us what you did" on the dark recorder.
class VoicePromptCard extends StatelessWidget {
  const VoicePromptCard({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: KnPrimitive.cream100.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(ImageConstants.onboardingVoice, width: 48, height: 48, fit: BoxFit.cover),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(LangKeys.voicePromptTitle.tr, style: text.label, color: KnPrimitive.cream50),
                const SizedBox(height: 2),
                CustomBaseTextWidget(LangKeys.voicePromptBody.tr, style: text.caption, color: KnPrimitive.cream400),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The big microphone, the time, the live waveform and the language chips.
class RecordingView extends StatelessWidget {
  const RecordingView({super.key, required this.controller});

  final VoiceRecordController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Obx(() {
              final level = controller.isRecording && controller.levels.isNotEmpty ? controller.levels.last : 0.0;
              return SizedBox.square(
                dimension: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final (size, alpha) in const [(260.0, 0.10), (200.0, 0.16), (150.0, 0.24)])
                      AnimatedScale(
                        scale: controller.isRecording ? 0.92 + level * 0.12 : 0.92,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kn.statusDanger.withValues(alpha: alpha),
                          ),
                        ),
                      ),
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: controller.isPaused ? KnPrimitive.mocha700 : kn.statusDanger,
                        boxShadow: KnShadow.lg,
                      ),
                      child: Icon(
                        controller.isPaused ? LucideIcons.pause : LucideIcons.mic,
                        size: 52,
                        color: KnPrimitive.cream50,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: controller.isPaused ? KnPrimitive.cream400 : kn.statusDanger,
                ),
              ),
              const SizedBox(width: KnSize.space8),
              CustomBaseTextWidget(
                controller.statusText,
                key: const ValueKey('voice-status'),
                style: text.h2,
                color: KnPrimitive.cream50,
              ),
            ],
          ),
        ),
        const SizedBox(height: KnSize.space16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Obx(
            () => VoiceWave(
              levels: controller.levels.toList(),
              color: KnPrimitive.cream400,
              playedColor: KnPrimitive.cream50,
              progress: controller.isPaused ? 0 : 0.6,
              height: 44,
            ),
          ),
        ),
        const SizedBox(height: KnSize.space24),
        CustomBaseTextWidget(LangKeys.voiceAnyLanguage.tr, style: text.body, color: KnPrimitive.cream400),
        const SizedBox(height: KnSize.space8),
        Obx(
          () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (code, name) in VoiceTexts.chips) ...[
                if (code != VoiceTexts.chips.first.$1) const SizedBox(width: KnSize.space8),
                _chip(context, code, name, selected: controller.language.value == code),
              ],
            ],
          ),
        ),
        const SizedBox(height: KnSize.space24),
      ],
    );
  }

  Widget _chip(BuildContext context, String code, String name, {required bool selected}) => Material(
        key: ValueKey('voice-lang-$code'),
        color: selected ? KnPrimitive.cream50 : KnPrimitive.cream100.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(KnSize.radiusFull),
        child: InkWell(
          borderRadius: BorderRadius.circular(KnSize.radiusFull),
          onTap: () => controller.onLanguageTap(code),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: KnSize.space4),
            child: CustomBaseTextWidget(
              name,
              // each name in its own script's font (as on the language screen)
              style: KnText.forLocale(Locale(code)).labelSm,
              color: selected ? KnPrimitive.mocha900 : KnPrimitive.cream50,
            ),
          ),
        ),
      );
}
