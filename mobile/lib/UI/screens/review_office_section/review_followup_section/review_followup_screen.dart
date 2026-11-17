import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_cover_image.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_initials_avatar.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../common_widgets/kn_stars.dart';
import '../../../common_widgets/kn_text_box.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../customer_section/customer_details_section/custom_widgets/customer_parts.dart';
import '../company_reviews_section/custom_widgets/review_office_parts.dart';
import 'review_followup_controller.dart';

/// M45 Low rating — follow up (Figma 265:4387).
class ReviewFollowupScreen extends GetView<ReviewFollowupController> {
  const ReviewFollowupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final top = MediaQuery.paddingOf(context).top;
    final r = controller.review;
    final tech = r.technician;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: kn.bgCanvas,
        body: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: Obx(
            () => ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: KnPrimitive.mocha900,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned(
                        right: -80,
                        top: -70,
                        child: Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: KnPrimitive.cream100.withValues(alpha: 0.10), width: 30),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(KnSize.space16, top + 12, KnSize.space16, KnSize.space24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                HeaderButton(
                                  key: const ValueKey('followup-back'),
                                  icon: LucideIcons.chevronLeft,
                                  label: MaterialLocalizations.of(context).backButtonTooltip,
                                  onTap: Get.back,
                                ),
                                const SizedBox(width: KnSize.space12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CustomBaseTextWidget(controller.title, style: text.h3, color: KnPrimitive.cream50),
                                      CustomBaseTextWidget(
                                        controller.subtitle,
                                        style: text.caption,
                                        color: KnPrimitive.cream400,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: KnSize.space16),
                            Row(
                              children: [
                                KnCoverImage(
                                  url: r.coverUrl,
                                  width: 48,
                                  height: 48,
                                  radius: KnSize.radiusMd,
                                  placeholderIcon: LucideIcons.wrench,
                                ),
                                const SizedBox(width: KnSize.space12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CustomBaseTextWidget(
                                        controller.who,
                                        style: text.label,
                                        color: KnPrimitive.cream50,
                                        maxLines: 2,
                                      ),
                                      const SizedBox(height: 4),
                                      KnStars(rating: r.rating, size: 14),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(KnSize.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(KnSize.space16),
                        decoration: BoxDecoration(
                          color: kn.bgSurface,
                          borderRadius: BorderRadius.circular(KnSize.radiusLg),
                          border: Border.all(
                            color: controller.resolved ? kn.borderDefault : kn.statusDanger,
                            width: controller.resolved ? 1 : 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (controller.quote != null) CustomBaseTextWidget(controller.quote!, style: text.bodyLg),
                            if (controller.tags.isNotEmpty) ...[
                              const SizedBox(height: KnSize.space12),
                              Wrap(
                                spacing: KnSize.space8,
                                runSpacing: KnSize.space8,
                                children: [for (final t in controller.tags) OfficePill(label: t, danger: true)],
                              ),
                            ],
                            if (controller.byLine.isNotEmpty) ...[
                              const SizedBox(height: KnSize.space12),
                              Row(
                                children: [
                                  if (tech != null) ...[
                                    KnInitialsAvatar(
                                      initials: TextUtils.initials(tech.name),
                                      size: 22,
                                      url: tech.avatarUrl,
                                      borderWidth: 0,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: CustomBaseTextWidget(
                                      controller.byLine,
                                      style: text.labelSm,
                                      color: kn.textSecondary,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (r.wantsCallBack) ...[
                        const SizedBox(height: KnSize.space12),
                        Container(
                          padding: const EdgeInsets.all(KnSize.space16),
                          decoration: BoxDecoration(
                            color: kn.bgSurface,
                            borderRadius: BorderRadius.circular(KnSize.radiusLg),
                            border: Border.all(color: kn.borderDefault),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(color: kn.statusDangerBg, shape: BoxShape.circle),
                                    child: Icon(LucideIcons.phone, size: 18, color: kn.statusDanger),
                                  ),
                                  const SizedBox(width: KnSize.space12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        CustomBaseTextWidget(LangKeys.crevAskedCall.tr, style: text.label),
                                        CustomBaseTextWidget(
                                          controller.callLine,
                                          style: text.caption,
                                          color: kn.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: KnSize.space12),
                              Row(
                                children: [
                                  Expanded(
                                    child: KnCustomButton(
                                      key: const ValueKey('followup-call'),
                                      text: LangKeys.crevCallNow.tr,
                                      icon: LucideIcons.phone,
                                      small: true,
                                      onTap: controller.onCallTap,
                                    ),
                                  ),
                                  const SizedBox(width: KnSize.space8),
                                  Expanded(
                                    child: KnCustomButton(
                                      key: const ValueKey('followup-revisit'),
                                      text: LangKeys.crevRevisit.tr,
                                      icon: LucideIcons.plus,
                                      small: true,
                                      variant: KnButtonVariant.secondary,
                                      onTap: controller.onRevisitTap,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: KnSize.space12),
                      Container(
                        padding: const EdgeInsets.all(KnSize.space16),
                        decoration: BoxDecoration(
                          color: kn.bgSurface,
                          borderRadius: BorderRadius.circular(KnSize.radiusLg),
                          border: Border.all(color: kn.borderDefault),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomBaseTextWidget(LangKeys.crevNote.tr, style: text.label),
                            const SizedBox(height: KnSize.space8),
                            KnTextBox(
                              fieldKey: const ValueKey('followup-note'),
                              controller: controller.note,
                              hint: LangKeys.crevNoteHint.tr,
                              minLines: 2,
                            ),
                            if (controller.noteChanged) ...[
                              const SizedBox(height: KnSize.space8),
                              IntrinsicWidth(
                                child: KnCustomButton(
                                  key: const ValueKey('followup-save-note'),
                                  text: LangKeys.crevSaveNote.tr,
                                  small: true,
                                  variant: KnButtonVariant.secondary,
                                  loading: controller.saving.value,
                                  onTap: controller.onSaveNote,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: KnScreenFooter(
          children: [
            Obx(
              () => Align(
                alignment: Alignment.centerLeft,
                child: IntrinsicWidth(
                  child: KnCustomButton(
                    key: const ValueKey('followup-resolve'),
                    text: controller.resolved ? LangKeys.crevReopen.tr : LangKeys.crevMarkResolved.tr,
                    icon: controller.resolved ? LucideIcons.rotateCcw : LucideIcons.check,
                    variant: controller.resolved ? KnButtonVariant.secondary : KnButtonVariant.primary,
                    loading: controller.saving.value,
                    onTap: controller.onResolveTap,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
