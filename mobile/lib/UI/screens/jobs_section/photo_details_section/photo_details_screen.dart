import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_cover_image.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_initials_avatar.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'photo_details_controller.dart';

/// M23 Photo details (Figma 26:1258, locked).
class PhotoDetailsScreen extends GetView<PhotoDetailsController> {
  const PhotoDetailsScreen({super.key});

  void _openNote(BuildContext context) {
    showKnBottomSheet<void>(
      title: LangKeys.photoAddNote.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('note-field'),
            controller: controller.noteController,
            autofocus: true,
            maxLines: 3,
            maxLength: 1000,
            style: context.knText.body,
            decoration: InputDecoration(
              hintText: LangKeys.photoNoteHint.tr,
              filled: true,
              fillColor: context.kn.bgSurface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(KnSize.radiusLg)),
            ),
          ),
          const SizedBox(height: KnSize.space12),
          Obx(
            () => KnCustomButton(
              key: const ValueKey('save-note'),
              text: LangKeys.photoSaveNote.tr,
              loading: controller.saving.value,
              onTap: controller.onSaveNoteTap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _round({required Key key, required IconData icon, required String label, required VoidCallback onTap}) =>
      CustomInkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        semanticLabel: label,
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: KnPrimitive.mocha950.withValues(alpha: 0.6), shape: BoxShape.circle),
          child: Icon(icon, size: 22, color: KnPrimitive.cream50),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kn.bgCanvas,
        bottomNavigationBar: KnScreenFooter(
          children: [
            KnCustomButton(
              key: const ValueKey('add-note'),
              text: LangKeys.photoAddNote.tr,
              icon: LucideIcons.pencil,
              variant: KnButtonVariant.secondary,
              onTap: () => _openNote(context),
            ),
            Obx(
              () => controller.canDelete
                  ? KnCustomButton(
                      key: const ValueKey('delete-photo'),
                      text: LangKeys.photoDelete.tr,
                      icon: LucideIcons.trash2,
                      variant: KnButtonVariant.ghost,
                      onTap: controller.onDeleteTap,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        body: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: SingleChildScrollView(
            child: Obx(() {
              final p = controller.photo.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: top + 288,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        KnCoverImage(url: p?.url, height: top + 288, placeholderIcon: LucideIcons.image),
                        Positioned(
                          left: KnSize.space16,
                          right: KnSize.space16,
                          top: top + 12,
                          child: Row(
                            children: [
                              _round(key: const ValueKey('photo-back'), icon: LucideIcons.chevronLeft, label: LangKeys.commonBack.tr, onTap: Get.back),
                              const Spacer(),
                              _round(key: const ValueKey('photo-share'), icon: LucideIcons.share, label: LangKeys.photoShare.tr, onTap: controller.onShareTap),
                            ],
                          ),
                        ),
                        if (p != null)
                          Positioned(
                            left: KnSize.space16,
                            bottom: KnSize.space16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
                              decoration: BoxDecoration(
                                color: KnPrimitive.mocha950.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(KnSize.radiusFull),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.camera, size: 14, color: KnPrimitive.cream50),
                                  const SizedBox(width: 6),
                                  CustomBaseTextWidget(controller.chip, style: text.labelSm, color: KnPrimitive.cream50),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (p != null)
                    Padding(
                      padding: const EdgeInsets.all(KnSize.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (p.locked) ...[
                            Container(
                              key: const ValueKey('photo-locked'),
                              padding: const EdgeInsets.all(KnSize.space12),
                              decoration: BoxDecoration(color: kn.borderDefault, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(color: kn.bgSurface, shape: BoxShape.circle),
                                    child: Icon(LucideIcons.lock, size: 18, color: kn.textPrimary),
                                  ),
                                  const SizedBox(width: KnSize.space12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CustomBaseTextWidget(LangKeys.photoLockedTitle.tr, style: text.label),
                                        CustomBaseTextWidget(LangKeys.photoLockedBody.tr, style: text.caption, color: kn.textSecondary),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: KnSize.space12),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: KnSize.space4),
                            decoration: BoxDecoration(
                              color: kn.bgSurface,
                              borderRadius: BorderRadius.circular(KnSize.radiusLg),
                              border: Border.all(color: kn.borderDefault),
                              boxShadow: KnShadow.sm,
                            ),
                            child: Column(
                              children: [
                                _row(
                                  context,
                                  LangKeys.photoStage.tr,
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
                                    decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.camera, size: 14, color: kn.textPrimary),
                                        const SizedBox(width: 6),
                                        CustomBaseTextWidget(controller.stageName(p.stage), style: text.labelSm),
                                      ],
                                    ),
                                  ),
                                ),
                                _row(context, LangKeys.photoTaken.tr, CustomBaseTextWidget(controller.taken, style: text.label)),
                                _row(
                                  context,
                                  LangKeys.photoBy.tr,
                                  Row(
                                    children: [
                                      KnInitialsAvatar(
                                        initials: TextUtils.initials(p.takenBy.name),
                                        url: p.takenBy.avatarUrl,
                                        size: 28,
                                        borderWidth: 0,
                                      ),
                                      const SizedBox(width: KnSize.space8),
                                      Expanded(child: CustomBaseTextWidget(p.takenBy.name, style: text.label, maxLines: 1)),
                                    ],
                                  ),
                                ),
                                if (controller.args.place != null && controller.args.place!.isNotEmpty)
                                  _row(
                                    context,
                                    LangKeys.photoPlace.tr,
                                    Row(
                                      children: [
                                        Icon(LucideIcons.mapPin, size: 16, color: kn.textPrimary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: CustomBaseTextWidget(controller.args.place!, style: text.label, maxLines: 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (controller.latestNote != null)
                                  _row(context, LangKeys.photoNote.tr, CustomBaseTextWidget(controller.latestNote!, style: text.body), last: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, Widget value, {bool last = false}) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: context.kn.borderDefault)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 84,
              child: CustomBaseTextWidget(label, style: context.knText.caption, color: context.kn.textSecondary),
            ),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: value)),
          ],
        ),
      );
}
