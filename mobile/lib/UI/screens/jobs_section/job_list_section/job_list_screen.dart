import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/custom_inkwell.dart';
import '../../../common_widgets/kn_back_button.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import 'custom_widgets/job_list_card.dart';
import 'custom_widgets/job_filters_sheet.dart';
import 'custom_widgets/job_list_parts.dart';
import 'job_list_controller.dart';

/// M14 Job list (Figma 43:958; no results 43:1089). A tab for managers; opened from Today for technicians.
class JobListScreen extends GetView<JobListController> {
  const JobListScreen({super.key, this.asTab = false});

  /// Inside the bottom tabs: no back button, room for the tab bar, and the + button.
  final bool asTab;

  @override
  Widget build(BuildContext context) {
    final kn = context.kn;
    final text = context.knText;
    return Scaffold(
      backgroundColor: kn.bgCanvas,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: asTab && controller.isManager
          ? Padding(
              padding: const EdgeInsets.only(bottom: 76),
              child: CustomInkWell(
                key: const ValueKey('new-job'),
                onTap: controller.onNewJobTap,
                borderRadius: BorderRadius.circular(28),
                semanticLabel: LangKeys.jobsNewJob.tr,
                child: Ink(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: kn.actionPrimary, shape: BoxShape.circle, boxShadow: KnShadow.md),
                  child: Icon(LucideIcons.plus, size: 26, color: kn.textOnAction),
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.load,
          child: ScrollConfiguration(
            behavior: const KnScrollBehavior(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(KnSize.space16, 12, KnSize.space16, asTab ? 160 : 32),
              children: [
                Row(
                  children: [
                    if (!asTab) ...[const KnBackButton(), const SizedBox(width: KnSize.space12)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomBaseTextWidget(LangKeys.jobsTitle.tr, style: text.h1),
                          Obx(
                            () => CustomBaseTextWidget(
                              controller.subtitle,
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
                      key: const ValueKey('job-filters'),
                      onTap: () => showJobFiltersSheet(controller),
                      borderRadius: BorderRadius.circular(22),
                      semanticLabel: LangKeys.jobsFilters.tr,
                      child: Obx(
                        () => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Ink(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: controller.sheetFilters > 0 ? kn.actionSecondary : kn.bgSurface,
                                shape: BoxShape.circle,
                                border: Border.all(color: kn.borderDefault),
                              ),
                              child: Icon(LucideIcons.slidersHorizontal, size: 22, color: kn.textPrimary),
                            ),
                            if (controller.sheetFilters > 0)
                              PositionedDirectional(
                                top: -2,
                                end: -2,
                                child: Container(
                                  key: const ValueKey('job-filters-count'),
                                  width: 18,
                                  height: 18,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: kn.actionPrimary, shape: BoxShape.circle),
                                  child: CustomBaseTextWidget(
                                    '${controller.sheetFilters}',
                                    style: context.knText.caption,
                                    color: kn.textOnAction,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Obx(
                  () => JobSearchField(
                    controller: controller.searchController,
                    onChanged: controller.onSearchChanged,
                    onClear: controller.onClearSearchTap,
                    active: controller.search.value.isNotEmpty,
                  ),
                ),
                const SizedBox(height: KnSize.space12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Obx(
                    () => Row(
                      children: [
                        for (final f in controller.filters) ...[
                          if (f != controller.filters.first) const SizedBox(width: 6),
                          JobFilterChip(
                            key: ValueKey('filter-${f.name}'),
                            label: f == controller.filter.value && controller.loaded.value
                                ? '${controller.chipLabel(f)} ${controller.jobs.length}'
                                : controller.chipLabel(f),
                            selected: f == controller.filter.value,
                            onTap: () => controller.onFilterTap(f),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: KnSize.space12),
                Obx(() => _results()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results() {
    if (!controller.loaded.value) {
      return Column(
        key: const ValueKey('jobs-loading'),
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(height: KnSize.space8),
            const CommonShimmer(height: 88, radius: KnSize.radiusLg),
          ],
        ],
      );
    }
    final jobs = controller.jobs;
    if (jobs.isEmpty) {
      final q = controller.search.value.trim();
      return JobListEmpty(
        title: q.isEmpty ? LangKeys.jobsNoneTitle.tr : LangKeys.jobsNoResultsTitle.trParams({'q': q}),
        body: q.isEmpty ? LangKeys.jobsNoneBody.tr : LangKeys.jobsNoResultsBody.tr,
        onClear: controller.hasFilters ? controller.onClearFiltersTap : null,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < jobs.length; i++) ...[
          if (i > 0) const SizedBox(height: KnSize.space8),
          JobListCard(
            job: jobs[i],
            time: controller.timeOf(jobs[i].scheduledAt),
            showAssignee: controller.showAssignee,
            onTap: () => controller.onJobTap(jobs[i]),
          ),
        ],
      ],
    );
  }
}
