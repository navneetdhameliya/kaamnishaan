import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../../jobs_section/job_list_section/custom_widgets/job_list_parts.dart';
import 'custom_widgets/my_report_card.dart';
import 'my_reports_controller.dart';

/// M30 My reports (Figma 30:1445).
class MyReportsScreen extends GetView<MyReportsController> {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: Obx(
              () => ListView(
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
                            CustomBaseTextWidget(LangKeys.meMyReports.tr, style: text.h3),
                            CustomBaseTextWidget(
                              LangKeys.myreportsSubtitle.trParams({'n': '${controller.total}'}),
                              style: text.caption,
                              color: kn.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KnSize.space16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final f in ReportFilter.values) ...[
                          if (f != ReportFilter.all) const SizedBox(width: KnSize.space8),
                          JobFilterChip(
                            key: ValueKey('report-filter-${f.name}'),
                            label: controller.filterLabel(f),
                            selected: controller.filter.value == f,
                            onTap: () => controller.onFilterTap(f),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: KnSize.space16),
                  if (!controller.loaded.value) ...const [
                    CommonShimmer(height: 150, radius: KnSize.radiusLg),
                    SizedBox(height: KnSize.space12),
                    CommonShimmer(height: 130, radius: KnSize.radiusLg),
                  ] else if (controller.reports.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: Column(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: kn.actionSecondary),
                            child: Icon(LucideIcons.fileText, size: 36, color: kn.textSecondary),
                          ),
                          const SizedBox(height: KnSize.space16),
                          CustomBaseTextWidget(LangKeys.myreportsNone.tr, style: text.h3, textAlign: TextAlign.center),
                          const SizedBox(height: KnSize.space4),
                          CustomBaseTextWidget(
                            LangKeys.myreportsNoneBody.tr,
                            style: text.body,
                            color: kn.textSecondary,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    for (final r in controller.reports) ...[
                      MyReportCard(
                        key: ValueKey('my-report-${r.id}'),
                        report: r,
                        meta: controller.meta(r),
                        when: controller.when(r),
                        status: controller.statusText(r),
                        onTap: () => controller.onOpen(r),
                        onFix: () => controller.onFixTap(r),
                      ),
                      const SizedBox(height: KnSize.space12),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
