import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../../infrastructure/shared/text_utils.dart';
import '../../../../common_widgets/kn_cover_image.dart';
import '../../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../../theme/kn_app_theme.dart';
import '../../../../theme/kn_tokens.g.dart';
import '../report_pdf_controller.dart';

/// The first page of the report, as the customer's PDF shows it.
class PdfPage extends StatelessWidget {
  const PdfPage({super.key, required this.controller});

  final ReportPdfController controller;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    final r = controller.report.value;
    final pair = controller.pair.value;
    Widget field(String label, String value, [String? more]) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomBaseTextWidget(label, style: text.caption, color: kn.textSecondary),
              CustomBaseTextWidget(value, style: text.label, maxLines: 2),
              if (more != null && more.isNotEmpty) CustomBaseTextWidget(more, style: text.caption, color: kn.textSecondary),
            ],
          ),
        );
    Widget photo(String? url, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(KnSize.radiusSm),
                child: AspectRatio(aspectRatio: 4 / 3, child: KnCoverImage(url: url)),
              ),
              const SizedBox(height: 4),
              CustomBaseTextWidget(label, style: text.captionStrong),
            ],
          ),
        );
    Widget section(String title, String? body) => (body ?? '').trim().isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: KnSize.space12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomBaseTextWidget(title, style: text.label),
                const SizedBox(height: 2),
                CustomBaseTextWidget(body!.trim(), style: text.caption.copyWith(fontSize: 14, height: 20 / 14)),
              ],
            ),
          );
    return Container(
      padding: const EdgeInsets.all(KnSize.space16),
      decoration: BoxDecoration(color: kn.bgSurface, borderRadius: BorderRadius.circular(KnSize.radiusSm), boxShadow: KnShadow.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(KnSize.radiusSm),
                child: controller.logo != null
                    ? KnCoverImage(url: controller.logo, width: 28, height: 28)
                    : Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        color: kn.actionPrimary,
                        child: CustomBaseTextWidget(TextUtils.initials(controller.company), style: text.captionStrong, color: kn.textOnAction),
                      ),
              ),
              const SizedBox(width: KnSize.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomBaseTextWidget(controller.company, style: text.label, maxLines: 1),
                    CustomBaseTextWidget(LangKeys.pdfServiceReport.tr, style: text.caption, color: kn.textSecondary),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CustomBaseTextWidget('#${controller.number}', style: text.label),
                  CustomBaseTextWidget(controller.date, style: text.caption, color: kn.textSecondary),
                ],
              ),
            ],
          ),
          const SizedBox(height: KnSize.space8),
          Container(height: 2, color: kn.textPrimary),
          const SizedBox(height: KnSize.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              field(LangKeys.pdfCustomer.tr, controller.customer),
              const SizedBox(width: KnSize.space8),
              field(LangKeys.pdfTechnician.tr, controller.technician, controller.workedAt),
            ],
          ),
          if (pair.before != null || pair.after != null) ...[
            const SizedBox(height: KnSize.space12),
            Row(
              children: [
                photo(pair.before?.url, LangKeys.stageBefore.tr),
                const SizedBox(width: KnSize.space8),
                photo(pair.after?.url, LangKeys.stageAfter.tr),
              ],
            ),
          ],
          section(LangKeys.pdfProblem.tr, r?.summary),
          section(LangKeys.reportWorkDone.tr, r?.workDone),
          if (controller.checksTotal > 0) ...[
            const SizedBox(height: KnSize.space12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: kn.statusSuccessBg, borderRadius: BorderRadius.circular(KnSize.radiusSm)),
              child: Row(
                children: [
                  Icon(LucideIcons.listChecks, size: 14, color: kn.statusSuccess),
                  const SizedBox(width: 6),
                  CustomBaseTextWidget(
                    LangKeys.pdfChecklist.trParams({'a': '${controller.checksPassed}', 'b': '${controller.checksTotal}'}),
                    style: text.captionStrong,
                    color: kn.statusSuccess,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: KnSize.space12),
          Row(
            children: [
              if (controller.approvedBy != null)
                Expanded(
                  child: CustomBaseTextWidget(
                    LangKeys.pdfApprovedBy.trParams({'name': controller.approvedBy!}),
                    style: text.caption,
                    color: kn.textSecondary,
                  ),
                )
              else
                const Spacer(),
              CustomBaseTextWidget('1 / ${controller.pages}', style: text.caption, color: kn.textSecondary),
            ],
          ),
        ],
      ),
    );
  }
}
