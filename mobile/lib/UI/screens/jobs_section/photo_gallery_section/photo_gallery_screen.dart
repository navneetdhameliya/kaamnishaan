import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/gallery_tiles.dart';
import 'photo_gallery_controller.dart';

/// M21 Photo gallery (Figma 22:1238).
class PhotoGalleryScreen extends GetView<PhotoGalleryController> {
  const PhotoGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('gallery-take-photo'),
            text: LangKeys.galleryTakePhoto.tr,
            icon: LucideIcons.camera,
            onTap: controller.onTakePhotoTap,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, 0),
              child: Row(
                children: [
                  const KnBackButton(),
                  const SizedBox(width: KnSize.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBaseTextWidget(LangKeys.galleryTitle.tr, style: text.h3),
                        Obx(
                          () => CustomBaseTextWidget(
                            LangKeys.gallerySubtitle.trParams({
                              'customer': controller.args.customer,
                              'count': '${controller.total}',
                            }),
                            style: text.caption,
                            color: kn.textSecondary,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: KnSize.space12),
                  CustomInkWell(
                    key: const ValueKey('gallery-camera'),
                    onTap: controller.onTakePhotoTap,
                    borderRadius: BorderRadius.circular(22),
                    semanticLabel: LangKeys.galleryTakePhoto.tr,
                    child: Ink(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kn.bgSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: kn.borderDefault),
                      ),
                      child: Icon(LucideIcons.camera, size: 22, color: kn.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: KnSize.space16),
              child: Obx(() => _tabs(context)),
            ),
            const SizedBox(height: KnSize.space16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.load,
                child: ScrollConfiguration(
                  behavior: const KnScrollBehavior(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(KnSize.space16, 0, KnSize.space16, KnSize.space24),
                    child: Obx(
                      () => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final s in PhotoGalleryController.stages) ...[
                            if (s != PhotoGalleryController.stages.first) const SizedBox(height: KnSize.space12),
                            _section(context, s),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Container(
      padding: const EdgeInsets.all(KnSize.space4),
      decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
      child: Row(
        children: [
          for (final s in PhotoGalleryController.stages) ...[
            if (s != PhotoGalleryController.stages.first) const SizedBox(width: KnSize.space4),
            Expanded(
              child: Builder(
                builder: (context) {
                  final on = controller.selected.value == s;
                  return CustomInkWell(
                    key: ValueKey('tab-$s'),
                    onTap: () => controller.onTabTap(s),
                    borderRadius: BorderRadius.circular(KnSize.radiusFull),
                    semanticLabel: controller.stageName(s),
                    child: Ink(
                      height: 40,
                      decoration: BoxDecoration(
                        color: on ? kn.bgSurface : Colors.transparent,
                        borderRadius: BorderRadius.circular(KnSize.radiusFull),
                        boxShadow: on ? KnShadow.sm : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: CustomBaseTextWidget(
                              controller.stageName(s),
                              style: text.label,
                              color: on ? kn.textPrimary : kn.textSecondary,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: KnSize.space8),
                            decoration: BoxDecoration(
                              color: on ? kn.actionPrimary : kn.bgSurface,
                              borderRadius: BorderRadius.circular(KnSize.radiusFull),
                            ),
                            child: CustomBaseTextWidget(
                              '${controller.photosOf(s).length}',
                              style: text.captionStrong,
                              color: on ? kn.textOnAction : kn.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String stage) {
    final photos = controller.photosOf(stage);
    return Column(
      key: controller.sectionKeys[stage],
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomBaseTextWidget(
          LangKeys.gallerySection.trParams({'stage': controller.stageName(stage), 'count': '${photos.length}'}),
          style: context.knText.label,
        ),
        const SizedBox(height: KnSize.space8),
        GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: KnSize.space8,
          crossAxisSpacing: KnSize.space8,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final p in photos)
              GalleryPhotoTile(photo: p, time: controller.timeOf(p.takenAt), onTap: () => controller.onPhotoTap(p)),
            GalleryAddTile(key: ValueKey('add-$stage'), onTap: () => controller.onTakePhotoTap(stage)),
          ],
        ),
      ],
    );
  }
}
