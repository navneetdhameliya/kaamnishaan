import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/compare_slider.dart';
import 'photo_pair_controller.dart';

/// M22 Before and after (Figma 26:1190).
class PhotoPairScreen extends GetView<PhotoPairController> {
  const PhotoPairScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: KnScreenFooter(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: KnCustomButton(
                  key: const ValueKey('pair-retake'),
                  text: LangKeys.pairRetake.tr,
                  variant: KnButtonVariant.secondary,
                  onTap: controller.onRetakeTap,
                ),
              ),
              const SizedBox(width: KnSize.space12),
              Expanded(
                flex: 3,
                child: Obx(
                  () => KnCustomButton(
                    key: const ValueKey('pair-use'),
                    text: controller.isSaved ? LangKeys.pairInReport.tr : LangKeys.pairUse.tr,
                    icon: LucideIcons.check,
                    loading: controller.saving.value,
                    enabled: controller.ready,
                    onTap: controller.onUseTap,
                    onDisabledTap: controller.onUseTap,
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
          padding: const EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, KnSize.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const KnBackButton(),
                  const SizedBox(width: KnSize.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomBaseTextWidget(LangKeys.pairTitle.tr, style: text.h3),
                        CustomBaseTextWidget(controller.args.customer, style: text.caption, color: kn.textSecondary, maxLines: 1),
                      ],
                    ),
                  ),
                  CustomInkWell(
                    key: const ValueKey('pair-choose'),
                    onTap: controller.onChooseTap,
                    borderRadius: BorderRadius.circular(22),
                    semanticLabel: LangKeys.pairChoose.tr,
                    child: Ink(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kn.bgSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: kn.borderDefault),
                      ),
                      child: Icon(LucideIcons.images, size: 22, color: kn.textPrimary),
                    ),
                  ),
                  const SizedBox(width: KnSize.space8),
                  CustomInkWell(
                    key: const ValueKey('pair-share'),
                    onTap: controller.onShareTap,
                    borderRadius: BorderRadius.circular(22),
                    semanticLabel: LangKeys.photoShare.tr,
                    child: Ink(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kn.bgSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: kn.borderDefault),
                      ),
                      child: Icon(LucideIcons.share, size: 22, color: kn.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Obx(() {
                  if (!controller.loaded.value) return const CommonShimmer(height: double.infinity, radius: KnSize.radiusLg);
                  return CompareSlider(
                    beforeUrl: controller.before.value?.url,
                    afterUrl: controller.after.value?.url,
                    split: controller.split.value,
                    onDrag: controller.onDrag,
                  );
                }),
              ),
              const SizedBox(height: KnSize.space16),
              Obx(
                () => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomBaseTextWidget(controller.title, style: text.h2, maxLines: 1),
                    CustomBaseTextWidget(controller.dateLine, style: text.caption, color: kn.textSecondary, maxLines: 1),
                    const SizedBox(height: KnSize.space12),
                    Row(
                      children: [
                        Expanded(child: _time(context, LangKeys.galleryBefore.tr, controller.timeOf(controller.before.value), kn.textPrimary)),
                        const SizedBox(width: KnSize.space8),
                        Expanded(child: _time(context, LangKeys.galleryAfter.tr, controller.timeOf(controller.after.value), kn.statusSuccess)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: KnSize.space12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.slidersHorizontal, size: 16, color: kn.textSecondary),
                  const SizedBox(width: 6),
                  CustomBaseTextWidget(LangKeys.pairDrag.tr, style: text.caption, color: kn.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _time(BuildContext context, String label, String time, Color iconColor) {
    final kn = context.kn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: 10),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.clock, size: 20, color: iconColor),
          const SizedBox(width: KnSize.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(label, style: context.knText.caption, color: kn.textSecondary),
                CustomBaseTextWidget(time.isEmpty ? '—' : time, style: context.knText.label, maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
