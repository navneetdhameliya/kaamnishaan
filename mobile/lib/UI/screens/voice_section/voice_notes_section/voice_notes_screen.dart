import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/commons/constants/image_constants.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/note_card.dart';
import 'voice_notes_controller.dart';

/// M28 Voice notes (Figma 28:1442).
class VoiceNotesScreen extends GetView<VoiceNotesController> {
  const VoiceNotesScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, NoteRow r) async {
    final yes = await showKnBottomSheet<bool>(
      title: LangKeys.notesDeleteTitle.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomBaseTextWidget(LangKeys.notesDeleteBody.tr, style: context.knText.body, color: context.kn.textSecondary),
          const SizedBox(height: KnSize.space16),
          KnCustomButton(
            key: const ValueKey('note-delete-yes'),
            text: LangKeys.notesDelete.tr,
            icon: LucideIcons.trash2,
            variant: KnButtonVariant.danger,
            onTap: () => Get.back<bool>(result: true),
          ),
          KnCustomButton(
            text: LangKeys.commonCancel.tr,
            variant: KnButtonVariant.ghost,
            onTap: () => Get.back<bool>(result: false),
          ),
        ],
      ),
    );
    if (yes == true) await controller.delete(r);
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('notes-record'),
            text: LangKeys.notesRecordNew.tr,
            icon: LucideIcons.mic,
            onTap: controller.onRecordTap,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: Obx(() {
              final rows = controller.rows;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                            CustomBaseTextWidget(LangKeys.notesTitle.tr, style: text.h3),
                            CustomBaseTextWidget(
                              LangKeys.notesCount.trParams({'customer': controller.args.customer, 'count': '${rows.length}'}),
                              style: text.caption,
                              color: kn.textSecondary,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space16),
                  if (!controller.loaded.value && rows.isEmpty) ...const [
                    CommonShimmer(height: 200, radius: KnSize.radiusLg),
                    SizedBox(height: KnSize.space12),
                    CommonShimmer(height: 140, radius: KnSize.radiusLg),
                  ] else if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: CustomBaseTextWidget(
                        LangKeys.notesNone.tr,
                        style: text.bodyLg,
                        color: kn.textSecondary,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    for (final r in rows) ...[
                      NoteCard(
                        key: ValueKey('note-${r.id}'),
                        row: r,
                        title: controller.title(r),
                        language: controller.language(r),
                        status: controller.statusText(r),
                        tone: controller.tone(r),
                        quote: controller.quote(r),
                        playing: controller.isPlaying(r),
                        progress: controller.progress(r),
                        onPlay: () => controller.onPlayTap(r),
                        onOpen: () => controller.onOpen(r),
                        onDelete: r.locked ? null : () => _confirmDelete(context, r),
                      ),
                      const SizedBox(height: KnSize.space12),
                    ],
                  const _TipCard(),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(color: kn.statusSuccessBg, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(ImageConstants.onboardingVoice, width: 56, height: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(LangKeys.notesTipTitle.tr, style: text.label),
                const SizedBox(height: 2),
                CustomBaseTextWidget(LangKeys.notesTipBody.tr, style: text.caption, color: kn.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
