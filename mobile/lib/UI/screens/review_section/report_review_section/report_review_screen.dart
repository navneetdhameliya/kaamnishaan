import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_custom_button.dart';
import '../../../common_widgets/kn_initials_avatar.dart';
import '../../../common_widgets/kn_screen_footer.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/changes_sheet.dart';
import 'custom_widgets/review_parts.dart';
import 'report_review_controller.dart';

/// M33 Report review (Figma 46:1322).
class ReportReviewScreen extends GetView<ReportReviewController> {
  const ReportReviewScreen({super.key});

  Future<void> _askForChanges() async {
    controller.prepareChanges();
    final sent = await showChangesSheet(controller);
    if (sent == true) Get.back<bool>(result: true);
  }

  /// M33 "…": open the job, see the PDF, or edit the report (when it can still change).
  void _openMore() {
    Widget item(String key, IconData icon, String label, VoidCallback onTap) => ListTile(
          key: ValueKey(key),
          leading: Icon(icon),
          title: CustomBaseTextWidget(label, style: Get.context!.knText.body),
          onTap: () {
            Get.back<void>();
            onTap();
          },
        );
    showKnBottomSheet<void>(
      title: LangKeys.reviewMore.tr,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item('review-more-job', LucideIcons.briefcase, LangKeys.reviewMoreJob.tr, controller.onOpenJobTap),
          item('review-more-pdf', LucideIcons.fileText, LangKeys.reviewMorePdf.tr, controller.onSeePdfTap),
          if (controller.canEdit)
            item('review-more-edit', LucideIcons.pencil, LangKeys.reviewMoreEdit.tr, controller.onEditTap),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      bottomNavigationBar: Obx(() {
        if (controller.waiting) {
          return KnScreenFooter(
            children: [
              Row(
                children: [
                  Expanded(
                    child: KnCustomButton(
                      key: const ValueKey('review-ask-changes'),
                      text: LangKeys.reviewAskChanges.tr,
                      variant: KnButtonVariant.secondary,
                      dense: true,
                      onTap: _askForChanges,
                    ),
                  ),
                  const SizedBox(width: KnSize.space12),
                  Expanded(
                    child: KnCustomButton(
                      key: const ValueKey('review-approve'),
                      text: LangKeys.reviewApprove.tr,
                      icon: LucideIcons.check,
                      dense: true,
                      loading: controller.approving.value,
                      onTap: controller.onApproveTap,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        if (controller.approved) {
          return KnScreenFooter(
            children: [
              Row(
                children: [
                  Expanded(
                    child: KnCustomButton(
                      key: const ValueKey('review-see-pdf'),
                      text: LangKeys.reviewSeePdf.tr,
                      icon: LucideIcons.fileText,
                      variant: KnButtonVariant.secondary,
                      dense: true,
                      onTap: controller.onSeePdfTap,
                    ),
                  ),
                  const SizedBox(width: KnSize.space12),
                  Expanded(
                    child: KnCustomButton(
                      key: const ValueKey('review-share'),
                      text: LangKeys.pdfShare.tr,
                      icon: LucideIcons.share,
                      dense: true,
                      onTap: controller.onShareTap,
                    ),
                  ),
                ],
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      }),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: Obx(() {
              final r = controller.report.value;
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
                            CustomBaseTextWidget(LangKeys.reviewTitle.tr, style: text.h3),
                            CustomBaseTextWidget(controller.subtitle, style: text.caption, color: kn.textSecondary, maxLines: 1),
                          ],
                        ),
                      ),
                      if (r != null)
                        CustomInkWell(
                          key: const ValueKey('review-more'),
                          onTap: _openMore,
                          borderRadius: BorderRadius.circular(22),
                          semanticLabel: LangKeys.reviewMore.tr,
                          child: SizedBox.square(
                            dimension: 44,
                            child: Icon(LucideIcons.ellipsis, size: 22, color: kn.textPrimary),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space16),
                  if (r == null) ...const [
                    CommonShimmer(height: 120, radius: KnSize.radiusLg),
                    SizedBox(height: KnSize.space12),
                    CommonShimmer(height: 220, radius: KnSize.radiusLg),
                  ] else ...[
                    Wrap(
                      spacing: KnSize.space8,
                      runSpacing: KnSize.space8,
                      children: [
                        ReviewChip(icon: LucideIcons.sparkle, label: controller.draftChip),
                        if (controller.sentChip != null) ReviewChip(icon: LucideIcons.clock, label: controller.sentChip!),
                        if (controller.approved)
                          ReviewChip(
                            icon: LucideIcons.check,
                            label: LangKeys.reportApproved.tr,
                            background: kn.statusSuccessBg,
                            foreground: kn.statusSuccess,
                          ),
                        if (r.status == 'changes_requested')
                          ReviewChip(
                            icon: LucideIcons.circleAlert,
                            label: LangKeys.reportChangesAsked.tr,
                            background: kn.statusDangerBg,
                            foreground: kn.statusDanger,
                          ),
                      ],
                    ),
                    const SizedBox(height: KnSize.space12),
                    CustomBaseTextWidget(controller.title, style: text.h2),
                    const SizedBox(height: KnSize.space4),
                    Row(
                      children: [
                        KnInitialsAvatar(
                          initials: TextUtils.initials(controller.techName),
                          url: r.job.technician?.avatarUrl,
                          size: 22,
                          borderWidth: 0,
                        ),
                        const SizedBox(width: KnSize.space8),
                        Expanded(child: CustomBaseTextWidget(controller.byLine, style: text.caption, color: kn.textSecondary)),
                      ],
                    ),
                    if (controller.photos.isNotEmpty) ...[
                      const SizedBox(height: KnSize.space12),
                      PhotoStrip(photos: controller.photos.toList(), onTap: controller.onPhotoTap),
                    ],
                    const SizedBox(height: KnSize.space12),
                    ProofRows(
                      rows: [
                        ProofRowData(
                          key: 'photos',
                          icon: LucideIcons.image,
                          label: LangKeys.reviewPhotos.tr,
                          value: '${controller.photoCount}',
                          onTap: controller.onPhotosTap,
                        ),
                        if (controller.checksTotal > 0)
                          ProofRowData(
                            key: 'checklist',
                            icon: LucideIcons.listChecks,
                            label: LangKeys.reviewChecklist.tr,
                            value: LangKeys.reviewOf.trParams({
                              'a': '${controller.checksPassed}',
                              'b': '${controller.checksTotal}',
                            }),
                            warn: controller.checksFailed > 0,
                            onTap: controller.onChecklistTap,
                          ),
                        if (controller.notes > 0)
                          ProofRowData(
                            key: 'voice',
                            icon: LucideIcons.mic,
                            label: LangKeys.reviewVoice.tr,
                            value: '${controller.notes}',
                            onTap: controller.onVoiceTap,
                          ),
                      ],
                    ),
                    if (controller.flags.isNotEmpty) ...[
                      const SizedBox(height: KnSize.space12),
                      AiCheckBanner(
                        title: controller.flagsTitle,
                        lines: controller.flags.map(controller.flagText).toList(),
                      ),
                    ],
                    for (final (title, body) in [
                      (LangKeys.reportSummary.tr, r.summary),
                      (LangKeys.reportWorkDone.tr, r.workDone),
                      (LangKeys.reportAdvice.tr, r.advice),
                    ])
                      if ((body ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: KnSize.space12),
                        WordsCard(
                          title: title,
                          body: body!.trim(),
                          onEdit: controller.canEdit ? controller.onEditTap : null,
                        ),
                      ],
                  ],
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
