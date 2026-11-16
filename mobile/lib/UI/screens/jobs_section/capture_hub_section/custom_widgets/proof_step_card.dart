import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/models/api_models.g.dart';
import '../../../../common_widgets/custom_inkwell.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../capture_hub_controller.dart';

/// M19 step row: photos (with up to 3 thumbnails), checklist (with a bar) or voice note.
/// [next] gets the dark border and "Next"; [locked] is the greyed "Not started" look (Figma 21:1150).
class ProofStepCard extends StatelessWidget {
  const ProofStepCard({super.key, required this.step, required this.next, required this.locked, required this.onTap});

  final ProofStepModel step;
  final bool next;
  final bool locked;
  final VoidCallback onTap;

  bool get _photos => const {'before', 'during', 'after'}.contains(step.key);

  IconData get _icon => switch (step.key) {
        'checklist' => LucideIcons.listChecks,
        'voice' => LucideIcons.mic,
        _ => LucideIcons.camera,
      };

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final radius = BorderRadius.circular(KnSize.radiusLg);
    final thumbs = step.thumbs ?? const <String>[];
    final card = Ink(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: radius,
        border: Border.all(color: next ? kn.actionPrimary : kn.borderDefault, width: next ? 2 : 1),
      ),
      child: Row(
        children: [
          if (_photos && thumbs.isNotEmpty && !locked)
            _thumbs(context, thumbs)
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: next ? kn.actionPrimary : kn.bgSubtle,
                borderRadius: BorderRadius.circular(KnSize.radiusMd),
              ),
              child: Icon(_icon, size: 24, color: next ? kn.textOnAction : kn.textPrimary),
            ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(CaptureHubController.stepTitle(step.key), style: text.label, maxLines: 1),
                const SizedBox(height: KnSize.space4),
                _detail(context),
              ],
            ),
          ),
          const SizedBox(width: KnSize.space12),
          _trailing(context),
        ],
      ),
    );
    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: CustomInkWell(
        key: ValueKey('step-${step.key}'),
        onTap: locked ? null : onTap,
        borderRadius: radius,
        semanticLabel: CaptureHubController.stepTitle(step.key),
        child: card,
      ),
    );
  }

  Widget _thumbs(BuildContext context, List<String> thumbs) {
    final shown = thumbs.take(3).toList();
    return SizedBox(
      width: 48 + 18.0 * (shown.length - 1),
      height: 48,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: 18.0 * i,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.kn.bgSurface, width: 2),
                ),
                child: KnCoverImage(url: shown[i], width: 44, height: 44, radius: 10, placeholderIcon: LucideIcons.image),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    if (locked) return CustomBaseTextWidget(LangKeys.hubNotStarted.tr, style: text.caption, color: kn.textSecondary);
    if (step.key == 'checklist') {
      final total = step.total ?? 0;
      if (total == 0) {
        return CustomBaseTextWidget(LangKeys.hubNoChecklist.tr, style: text.caption, color: kn.textSecondary, maxLines: 1);
      }
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: step.count / total,
                minHeight: 6,
                backgroundColor: kn.bgSubtle,
                color: step.done ? kn.statusSuccess : kn.actionPrimary,
              ),
            ),
          ),
          const SizedBox(width: KnSize.space8),
          CustomBaseTextWidget(
            LangKeys.hubOf.trParams({'done': '${step.count}', 'total': '$total'}),
            style: text.caption,
            color: kn.textSecondary,
          ),
        ],
      );
    }
    final (String label, Color color) = switch (step.key) {
      'voice' when step.count > 0 => (LangKeys.hubNotesAdded.trParams({'count': '${step.count}'}), kn.statusSuccess),
      'voice' => (LangKeys.hubSayWhat.tr, kn.textSecondary),
      _ when step.count == 1 => (LangKeys.hubPhotoAdded.tr, kn.statusSuccess),
      _ when step.count > 1 => (LangKeys.hubPhotosAdded.trParams({'count': '${step.count}'}), kn.statusSuccess),
      _ when next => (LangKeys.hubTakeNow.tr, kn.textPrimary),
      _ when !step.requiredValue => (LangKeys.hubOptional.tr, kn.textSecondary),
      _ => (LangKeys.hubNotYet.tr, kn.textSecondary),
    };
    return CustomBaseTextWidget(label, style: text.caption, color: color, maxLines: 1);
  }

  Widget _trailing(BuildContext context) {
    final kn = context.kn;
    if (locked) return Icon(LucideIcons.lock, size: 20, color: kn.textSecondary);
    if (next) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
        decoration: BoxDecoration(color: kn.actionPrimary, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
        child: CustomBaseTextWidget(LangKeys.hubNext.tr, style: context.knText.labelSm, color: kn.textOnAction),
      );
    }
    if (step.done && step.key != 'checklist' && step.key != 'voice') {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: kn.statusSuccess, shape: BoxShape.circle),
        child: const Icon(LucideIcons.check, size: 16, color: KnPrimitive.cream50),
      );
    }
    return Icon(LucideIcons.chevronRight, size: 20, color: kn.textPrimary);
  }
}
