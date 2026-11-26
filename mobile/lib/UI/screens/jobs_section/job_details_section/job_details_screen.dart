import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_cover_image.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_job_status_pill.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/job_info_cards.dart';
import 'custom_widgets/office_sheets.dart';
import 'custom_widgets/review_card.dart';
import 'job_details_controller.dart';

/// M15 Job details (Figma 20:1050). The live map comes later (D-54); the top shows the site's photo.
class JobDetailsScreen extends GetView<JobDetailsController> {
  const JobDetailsScreen({super.key});

  /// Design: picture 280 tall measured with a 32 px status bar; the sheet starts at 240.
  static const _pictureHeight = 248.0;
  static const _sheetTop = 208.0;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final top = MediaQuery.paddingOf(context).top;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.onBackTap();
      },
      child: Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: Obx(() => _footer() ?? const SizedBox.shrink()),
      body: ScrollConfiguration(
        behavior: const KnScrollBehavior(),
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Stack(
              children: [
                Obx(
                  () => KnCoverImage(
                    url: controller.job.value?.coverUrl,
                    height: top + _pictureHeight,
                    width: double.infinity,
                    placeholderIcon: LucideIcons.mapPin,
                  ),
                ),
                Positioned(
                  left: KnSize.space16,
                  right: KnSize.space16,
                  top: top + 12,
                  child: Row(
                    children: [
                      KnBackButton(onTap: controller.onBackTap),
                      const Spacer(),
                      Obx(
                        () => controller.hasMenu
                            ? Padding(
                                padding: const EdgeInsetsDirectional.only(end: KnSize.space8),
                                child: CustomInkWell(
                                  key: const ValueKey('job-menu'),
                                  onTap: () => showJobOfficeMenu(controller),
                                  borderRadius: BorderRadius.circular(22),
                                  semanticLabel: LangKeys.jobMenu.tr,
                                  child: Ink(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: kn.bgSurface,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: kn.borderDefault),
                                    ),
                                    child: Icon(LucideIcons.ellipsis, size: 22, color: kn.textPrimary),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      CustomInkWell(
                        key: const ValueKey('read-job'),
                        onTap: controller.onSpeakTap,
                        borderRadius: BorderRadius.circular(22),
                        semanticLabel: LangKeys.jobReadAloud.tr,
                        child: Ink(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: kn.bgSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: kn.borderDefault),
                          ),
                          child: Icon(LucideIcons.volume2, size: 22, color: kn.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: top + _sheetTop),
                  padding: const EdgeInsets.fromLTRB(KnSize.space16, 14, KnSize.space16, KnSize.space24),
                  decoration: BoxDecoration(
                    color: kn.bgCanvas,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(KnSize.radiusXl)),
                  ),
                  child: Obx(() => _sheet(context)),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _sheet(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final job = controller.job.value;
    if (job == null) {
      return Column(
        key: const ValueKey('job-loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomBaseTextWidget(controller.customer, style: text.h1),
          const SizedBox(height: KnSize.space16),
          const CommonShimmer(height: 48, radius: KnSize.radiusLg),
          const SizedBox(height: KnSize.space12),
          const CommonShimmer(height: 62, radius: KnSize.radiusLg),
          const SizedBox(height: KnSize.space12),
          const CommonShimmer(height: 58, radius: KnSize.radiusLg),
        ],
      );
    }
    final contact = job.contact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            KnJobStatusPill(status: job.status),
            const Spacer(),
            if (controller.when.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
                decoration: BoxDecoration(color: kn.bgSubtle, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.clock, size: 14, color: kn.textPrimary),
                    const SizedBox(width: 6),
                    CustomBaseTextWidget(controller.when, style: text.labelSm),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: KnSize.space12),
        if (controller.canOpenCustomer)
          CustomInkWell(
            key: const ValueKey('job-customer'),
            onTap: controller.onCustomerTap,
            borderRadius: BorderRadius.circular(KnSize.radiusMd),
            child: Row(
              children: [
                Flexible(child: CustomBaseTextWidget(controller.customer, style: text.h1)),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight, size: 24, color: kn.textSecondary),
              ],
            ),
          )
        else
          CustomBaseTextWidget(controller.customer, style: text.h1),
        if (controller.address.isNotEmpty) ...[
          const SizedBox(height: KnSize.space2),
          CustomBaseTextWidget(controller.address, style: text.body, color: kn.textSecondary),
        ],
        if (controller.distance.value case final d?) ...[
          const SizedBox(height: KnSize.space2),
          CustomBaseTextWidget(d, key: const ValueKey('job-distance'), style: text.caption, color: kn.textSecondary),
        ],
        const SizedBox(height: KnSize.space12),
        Row(
          children: [
            Expanded(
              child: KnCustomButton(
                key: const ValueKey('navigate'),
                text: LangKeys.jobNavigate.tr,
                icon: LucideIcons.mapPin,
                height: 48,
                onTap: controller.address.isEmpty ? null : controller.onNavigateTap,
              ),
            ),
            const SizedBox(width: KnSize.space8),
            Expanded(
              child: KnCustomButton(
                key: const ValueKey('call'),
                text: LangKeys.jobCall.tr,
                icon: LucideIcons.phone,
                height: 48,
                variant: KnButtonVariant.secondary,
                onTap: contact?.phone == null ? null : controller.onCallTap,
              ),
            ),
          ],
        ),
        if (job.review != null) ...[
          const SizedBox(height: KnSize.space12),
          ReviewCard(
            review: job.review!,
            words: controller.reviewWords,
            busy: controller.askingReview.value,
            onRequest: controller.onRequestReviewTap,
            onCancel: controller.onCancelReviewTap,
            onOpen: controller.onOpenReviewTap,
          ),
        ],
        if (contact != null) ...[
          const SizedBox(height: KnSize.space12),
          JobContactCard(name: contact.name, title: contact.title),
        ],
        if (controller.problem.isNotEmpty) ...[
          const SizedBox(height: KnSize.space12),
          JobProblemCard(problem: controller.problem),
        ],
        if (job.equipment != null) ...[
          const SizedBox(height: KnSize.space12),
          JobEquipmentCard(
            name: controller.equipmentName,
            info: controller.equipmentInfo,
            onTap: controller.onEquipmentTap,
          ),
        ],
      ],
    );
  }

  Widget? _footer() {
    if (controller.canStart) {
      return KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('start-job'),
            text: LangKeys.jobStart.tr,
            icon: LucideIcons.play,
            loading: controller.starting.value,
            onTap: controller.onStartTap,
          ),
        ],
      );
    }
    if (controller.showAssignButton) {
      return KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('assign-job'),
            text: LangKeys.jobAssign.tr,
            icon: LucideIcons.userCheck,
            onTap: controller.onAssignTap,
          ),
        ],
      );
    }
    if (controller.canContinue) {
      return KnScreenFooter(
        children: [
          KnCustomButton(
            key: const ValueKey('continue-job'),
            text: LangKeys.jobContinue.tr,
            icon: LucideIcons.camera,
            onTap: controller.onContinueTap,
          ),
        ],
      );
    }
    return null;
  }
}
