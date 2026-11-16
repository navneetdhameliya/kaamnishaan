import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/commons/constants/image_constants.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_photo_badge.dart';
import '../../../common_widgets/kn_progress_dots.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/intro_slide.dart';
import 'intro_controller.dart';

/// M03 Onboarding 1–3 (Figma 15:903, 69:1979, 69:2014).
class IntroScreen extends GetView<IntroController> {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    Widget dots(int i) => KnProgressDots(count: IntroController.pageCount, index: i);
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Obx(
                () => Align(
                  alignment: Alignment.centerRight,
                  child: controller.isLast
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(right: KnSize.space4),
                          child: CustomInkWell(
                            onTap: controller.finish,
                            borderRadius: BorderRadius.circular(KnSize.radiusMd),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: KnSize.space12, vertical: KnSize.space8),
                              child: CustomBaseTextWidget(
                                LangKeys.commonSkip.tr,
                                style: context.knText.label,
                                color: kn.textLink,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: controller.pageController,
                onPageChanged: controller.onPageChanged,
                children: [
                  IntroSlide(
                    image: ImageConstants.onboardingPhotos,
                    topBadge: KnPhotoBadge(text: LangKeys.introPhotosBadge.tr, icon: LucideIcons.camera),
                    bottomBadge: KnPhotoBadge(
                      text: LangKeys.introPhotosSaved.tr,
                      icon: LucideIcons.check,
                      tone: KnBadgeTone.success,
                    ),
                    title: LangKeys.introPhotosTitle.tr,
                    body: LangKeys.introPhotosBody.tr,
                    dots: dots(0),
                  ),
                  IntroSlide(
                    image: ImageConstants.onboardingVoice,
                    topBadge: KnPhotoBadge(text: LangKeys.introVoiceBadge.tr, icon: LucideIcons.mic, dot: true),
                    bottomBadge: KnPhotoBadge(
                      text: LangKeys.introVoiceWritten.tr,
                      icon: LucideIcons.sparkles,
                      tone: KnBadgeTone.success,
                    ),
                    title: LangKeys.introVoiceTitle.tr,
                    body: LangKeys.introVoiceBody.tr,
                    dots: dots(1),
                  ),
                  IntroSlide(
                    image: ImageConstants.onboardingReport,
                    topBadge: KnPhotoBadge(text: LangKeys.introReportBadge.tr, icon: LucideIcons.check),
                    bottomBadge: KnPhotoBadge(
                      text: LangKeys.introReportSent.trParams({'count': '6'}),
                      icon: LucideIcons.image,
                      tone: KnBadgeTone.success,
                    ),
                    title: LangKeys.introReportTitle.tr,
                    body: LangKeys.introReportBody.tr,
                    dots: dots(2),
                  ),
                ],
              ),
            ),
            KnScreenFooter(
              children: [
                Obx(
                  () => KnCustomButton(
                    key: const ValueKey('intro-next'),
                    text: controller.isLast ? LangKeys.introGetStarted.tr : LangKeys.commonNext.tr,
                    icon: LucideIcons.chevronRight,
                    onTap: controller.onNextTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
