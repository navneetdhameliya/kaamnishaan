import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/shared/time_utils.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../../common/voice_wave.dart';
import '../voice_notes_controller.dart';

/// One note on M28: play, length and language, delete, waveform, status, and the written text.
class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.row,
    required this.title,
    required this.language,
    required this.status,
    required this.tone,
    required this.quote,
    required this.playing,
    required this.progress,
    required this.onPlay,
    required this.onOpen,
    this.onDelete,
  });

  final NoteRow row;
  final String title;
  final String language;
  final String status;
  final NoteTone tone;
  final String? quote;
  final bool playing;
  final double progress;
  final VoidCallback onPlay;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final seconds = row.seconds;
    return CustomInkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(KnSize.radiusLg),
      child: Container(
        padding: const EdgeInsets.all(KnSize.space16),
        decoration: BoxDecoration(
          color: kn.bgSurface,
          borderRadius: BorderRadius.circular(KnSize.radiusLg),
          border: Border.all(color: kn.borderDefault),
          boxShadow: KnShadow.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (row.typed)
                  _circle(kn.actionSecondary, Icon(LucideIcons.pencil, size: 20, color: kn.textPrimary))
                else
                  CustomInkWell(
                    key: ValueKey('note-play-${row.id}'),
                    onTap: onPlay,
                    borderRadius: BorderRadius.circular(22),
                    child: _circle(
                      kn.actionPrimary,
                      Icon(playing ? LucideIcons.pause : LucideIcons.play, size: 22, color: kn.textOnAction),
                    ),
                  ),
                const SizedBox(width: KnSize.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CustomBaseTextWidget(title, style: text.label, maxLines: 1),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (seconds != null) ...[
                            Icon(LucideIcons.clock, size: 14, color: kn.textSecondary),
                            const SizedBox(width: 4),
                            CustomBaseTextWidget(
                              TimeUtils.minSec(Duration(milliseconds: (seconds * 1000).round())),
                              style: text.caption,
                              color: kn.textSecondary,
                            ),
                            const SizedBox(width: KnSize.space8),
                          ],
                          if (language.isNotEmpty) ...[
                            Icon(LucideIcons.globe, size: 14, color: kn.textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: CustomBaseTextWidget(language, style: text.caption, color: kn.textSecondary, maxLines: 1),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  CustomInkWell(
                    key: ValueKey('note-delete-${row.id}'),
                    onTap: onDelete!,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
                      child: Icon(LucideIcons.trash2, size: 20, color: kn.statusDanger),
                    ),
                  ),
              ],
            ),
            if (!row.typed) ...[
              const SizedBox(height: KnSize.space12),
              VoiceWave(
                seed: row.id,
                progress: progress,
                color: tone == NoteTone.done ? kn.textPrimary : kn.textSecondary.withValues(alpha: 0.6),
                playedColor: kn.statusDanger,
                height: 22,
                barWidth: 2.5,
                gap: 3,
              ),
            ],
            const SizedBox(height: KnSize.space12),
            _StatusChip(text: status, tone: tone),
            if (quote != null) ...[
              const SizedBox(height: KnSize.space12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(KnSize.space12),
                decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                child: CustomBaseTextWidget(quote!, style: text.body, maxLines: 3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _circle(Color color, Widget child) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Center(child: child),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.tone});

  final String text;
  final NoteTone tone;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final (Color bg, Color fg, IconData icon) = switch (tone) {
      NoteTone.done => (kn.statusSuccessBg, kn.statusSuccess, LucideIcons.check),
      NoteTone.working => (kn.actionSecondary, kn.textSecondary, LucideIcons.rotateCw),
      NoteTone.problem => (kn.statusDangerBg, kn.statusDanger, LucideIcons.circleAlert),
      NoteTone.phone => (kn.statusOfflineBg, kn.statusOffline, LucideIcons.cloudOff),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          CustomBaseTextWidget(text, style: context.knText.labelSm, color: fg),
        ],
      ),
    );
  }
}
