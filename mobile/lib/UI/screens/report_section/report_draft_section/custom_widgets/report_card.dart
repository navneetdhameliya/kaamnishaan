import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/shared/text_utils.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../common_widgets/kn_custom_button.dart';
import '../../../../common_widgets/kn_initials_avatar.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../report_draft_controller.dart';

/// The report as the customer will see it: company, customer, who and when, before/after, the words.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.controller});

  final ReportDraftController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final r = controller.report.value!;
    final pair = controller.pair.value;
    final company = controller.companyName;
    final e = r.evidence;
    Widget section(String title, String? body) {
      if (body == null || body.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: KnSize.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomBaseTextWidget(title, style: text.label),
            const SizedBox(height: KnSize.space4),
            CustomBaseTextWidget(body.trim(), style: text.body),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(
        color: kn.bgSurface,
        borderRadius: BorderRadius.circular(KnSize.radiusLg),
        border: Border.all(color: kn.borderDefault),
        boxShadow: KnShadow.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(KnSize.radiusSm),
                child: controller.companyLogo != null
                    ? KnCoverImage(url: controller.companyLogo, width: 28, height: 28)
                    : Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        color: kn.actionPrimary,
                        child: CustomBaseTextWidget(TextUtils.initials(company), style: text.captionStrong, color: kn.textOnAction),
                      ),
              ),
              const SizedBox(width: KnSize.space8),
              Expanded(child: CustomBaseTextWidget(company, style: text.label, maxLines: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kn.actionSecondary, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.globe, size: 14, color: kn.textPrimary),
                    const SizedBox(width: 4),
                    CustomBaseTextWidget(controller.language, style: text.labelSm),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KnSize.space12),
          Divider(height: 1, color: kn.borderDefault),
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(r.job.customer, style: text.h2),
          const SizedBox(height: KnSize.space4),
          Row(
            children: [
              KnInitialsAvatar(
                initials: TextUtils.initials(r.job.technician?.name ?? ''),
                url: controller.technicianAvatar,
                size: 20,
                borderWidth: 0,
              ),
              const SizedBox(width: KnSize.space8),
              Expanded(child: CustomBaseTextWidget(controller.byLine, style: text.caption, color: kn.textSecondary)),
            ],
          ),
          if (pair.before != null || pair.after != null) ...[
            const SizedBox(height: KnSize.space12),
            Row(
              children: [
                Expanded(child: _photo(context, pair.before?.url, LangKeys.cameraStageBefore.tr, KnPrimitive.mocha950.withValues(alpha: 0.7))),
                const SizedBox(width: KnSize.space8),
                Expanded(child: _photo(context, pair.after?.url, LangKeys.cameraStageAfter.tr, KnPrimitive.green650)),
              ],
            ),
          ],
          section(LangKeys.reportSummary.tr, r.summary),
          section(LangKeys.reportWorkDone.tr, r.workDone),
          section(LangKeys.reportAdvice.tr, r.advice),
          if (e.checksPassed > 0 || e.checksFailed > 0) ...[
            const SizedBox(height: KnSize.space12),
            Wrap(
              spacing: KnSize.space8,
              runSpacing: KnSize.space8,
              children: [
                if (e.checksPassed > 0)
                  _chip(context, LucideIcons.check, LangKeys.reportChecksPassed.trParams({'n': '${e.checksPassed}'}), kn.statusSuccessBg, kn.statusSuccess),
                if (e.checksFailed > 0)
                  _chip(context, LucideIcons.circleAlert, LangKeys.reportToFix.trParams({'n': '${e.checksFailed}'}), kn.statusWarningBg, kn.statusWarning),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _photo(BuildContext context, String? url, String label, Color tagColor) => ClipRRect(
        borderRadius: BorderRadius.circular(KnSize.radiusMd),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              KnCoverImage(url: url),
              Positioned(
                left: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
                  child: CustomBaseTextWidget(label, style: context.knText.captionStrong, color: KnPrimitive.cream50),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _chip(BuildContext context, IconData icon, String label, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusFull)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 6),
            CustomBaseTextWidget(label, style: context.knText.labelSm, color: fg),
          ],
        ),
      );
}

/// "Missing: after photo of outdoor unit" with "Take photo".
class MissingBanner extends StatelessWidget {
  const MissingBanner({super.key, required this.text, required this.onTakePhoto});

  final String text;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    return Container(
      padding: const EdgeInsets.fromLTRB(KnSize.space12, KnSize.space8, KnSize.space8, KnSize.space8),
      decoration: BoxDecoration(color: kn.statusWarningBg, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert, size: 20, color: kn.statusWarning),
          const SizedBox(width: KnSize.space8),
          Expanded(
            child: CustomBaseTextWidget(
              LangKeys.reportMissing.trParams({'what': text}),
              style: context.knText.labelSm,
              maxLines: 3,
            ),
          ),
          const SizedBox(width: KnSize.space8),
          KnCustomButton(
            key: const ValueKey('report-take-photo'),
            text: LangKeys.reportTakePhoto.tr,
            variant: KnButtonVariant.secondary,
            small: true,
            onTap: onTakePhoto,
          ),
        ],
      ),
    );
  }
}

/// After sending: waiting for the manager, changes asked (with their note), or approved.
class StateBanner extends StatelessWidget {
  const StateBanner({super.key, required this.text, required this.status, this.note});

  final String text;
  final String status;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final textStyles = context.knText;
    final (Color bg, Color fg, IconData icon) = switch (status) {
      'changes_requested' => (kn.statusDangerBg, kn.statusDanger, LucideIcons.circleAlert),
      'pending_review' => (kn.actionSecondary, kn.textPrimary, LucideIcons.clock),
      _ => (kn.statusSuccessBg, kn.statusSuccess, LucideIcons.check),
    };
    return Container(
      padding: const EdgeInsets.all(KnSize.space12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(KnSize.radiusLg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: KnSize.space8),
              Expanded(child: CustomBaseTextWidget(text, style: textStyles.label, color: fg)),
            ],
          ),
          if (note != null && note!.trim().isNotEmpty) ...[
            const SizedBox(height: KnSize.space4),
            CustomBaseTextWidget('“${note!.trim()}”', style: textStyles.body),
          ],
          if (status == 'pending_review') ...[
            const SizedBox(height: KnSize.space4),
            CustomBaseTextWidget(LangKeys.reportLocked.tr, style: textStyles.caption, color: kn.textSecondary),
          ],
        ],
      ),
    );
  }
}
