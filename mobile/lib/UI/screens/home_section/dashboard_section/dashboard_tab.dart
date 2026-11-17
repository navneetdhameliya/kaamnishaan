import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/common_shimmer.dart';
import '../../../common_widgets/kn_text_link.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../home_shell_section/custom_widgets/home_header.dart';
import 'custom_widgets/get_started_card.dart';
import 'custom_widgets/how_it_works_card.dart';
import 'custom_widgets/review_card.dart';
import 'custom_widgets/stat_tile.dart';
import 'custom_widgets/team_member_card.dart';
import 'custom_widgets/week_summary.dart';
import 'dashboard_controller.dart';

/// M13 Dashboard (Figma 41:879; new company 42:901).
class DashboardTab extends GetView<DashboardController> {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: RefreshIndicator(
        onRefresh: controller.load,
        edgeOffset: top,
        child: ScrollConfiguration(
          behavior: const KnScrollBehavior(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Obx(() {
              final data = controller.data.value;
              final fresh = controller.isNewCompany;
              // design heights below a 32 px status bar: header 264 (new company 248), cards 56 px above its end
              final headerHeight = fresh ? 216.0 : 232.0;
              return Stack(
                children: [
                  HomeHeader(
                    top: top,
                    height: headerHeight,
                    greeting: fresh ? LangKeys.homeWelcome.tr : controller.greeting,
                    name: controller.firstName,
                    initials: controller.initials,
                    avatarUrl: controller.avatarUrl,
                    ringLeft: 210,
                    ringTop: -122,
                    unread: (data?.unread ?? 0) > 0,
                    onBell: controller.onBellTap,
                    child: data == null ? null : (fresh ? _intro(context) : _week(context)),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(KnSize.space16, top + headerHeight - 56, KnSize.space16, 112),
                    child: data == null
                        ? _loading()
                        : fresh
                            ? _newCompany(context)
                            : _running(context),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _week(BuildContext context) {
    final d = controller.data.value!;
    return Padding(
      padding: const EdgeInsets.only(top: KnSize.space4),
      child: WeekSummary(
        total: d.reportsWeek,
        week: d.week,
        trend: controller.trend,
        trendText: controller.trendText,
        dayLetter: (day) => TimeUtils.dayLetter(day, controller.translation.currentCode),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final text = context.knText;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: KnSize.space4),
            decoration: BoxDecoration(
              color: KnPrimitive.cream100.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(KnSize.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.check, size: 14, color: KnPrimitive.cream50),
                const SizedBox(width: 6),
                Flexible(
                  child: CustomBaseTextWidget(
                    LangKeys.dashRoleCompany.trParams({'role': controller.roleLabel, 'company': controller.companyName}),
                    style: text.labelSm,
                    color: KnPrimitive.cream50,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KnSize.space12),
          CustomBaseTextWidget(LangKeys.dashSetUpTeam.tr, style: text.h2, color: KnPrimitive.cream50),
        ],
      ),
    );
  }

  Widget _loading() => const Column(
        key: ValueKey('dashboard-loading'),
        children: [
          Row(
            children: [
              Expanded(child: CommonShimmer(height: 118, radius: KnSize.radiusLg)),
              SizedBox(width: KnSize.space8),
              Expanded(child: CommonShimmer(height: 118, radius: KnSize.radiusLg)),
              SizedBox(width: KnSize.space8),
              Expanded(child: CommonShimmer(height: 118, radius: KnSize.radiusLg)),
            ],
          ),
          SizedBox(height: KnSize.space16),
          CommonShimmer(height: 84, radius: KnSize.radiusLg),
          SizedBox(height: 10),
          CommonShimmer(height: 84, radius: KnSize.radiusLg),
        ],
      );

  Widget _section(BuildContext context, String title, {VoidCallback? onSeeAll}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Expanded(child: CustomBaseTextWidget(title, style: context.knText.h3, maxLines: 1)),
            if (onSeeAll != null) KnTextLink(text: LangKeys.commonSeeAll.tr, large: true, onTap: onSeeAll),
          ],
        ),
      );

  Widget _running(BuildContext context) {
    final kn = context.kn;
    final d = controller.data.value!;
    final reviews = controller.reviews;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                key: const ValueKey('tile-review'),
                icon: LucideIcons.fileText,
                iconColor: kn.statusWarning,
                iconBg: kn.statusWarningBg,
                value: d.toReview,
                label: LangKeys.dashToReview.tr,
                highlight: d.toReview > 0 ? kn.statusWarning : null,
                onTap: controller.onReviewTilesTap,
              ),
            ),
            const SizedBox(width: KnSize.space8),
            Expanded(
              child: StatTile(
                icon: LucideIcons.clock,
                iconColor: kn.textPrimary,
                iconBg: kn.bgSubtle,
                value: controller.todayCount('in_progress'),
                label: LangKeys.dashInProgress.tr,
                onTap: controller.onJobTilesTap,
              ),
            ),
            const SizedBox(width: KnSize.space8),
            Expanded(
              child: StatTile(
                icon: LucideIcons.check,
                iconColor: kn.statusSuccess,
                iconBg: kn.statusSuccessBg,
                value: controller.todayCount('done'),
                label: LangKeys.dashDoneToday.tr,
                onTap: controller.onJobTilesTap,
              ),
            ),
          ],
        ),
        const SizedBox(height: KnSize.space16),
        if (reviews.isEmpty)
          InfoRowCard(
            icon: LucideIcons.fileText,
            title: LangKeys.dashNoReports.tr,
            body: LangKeys.dashNoReportsBody.tr,
          )
        else ...[
          _section(context, LangKeys.dashWaiting.tr, onSeeAll: controller.onReviewTilesTap),
          for (var i = 0; i < reviews.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            ReviewCard(
              report: reviews[i],
              meta: controller.reviewMeta(reviews[i]),
              evidence: controller.reviewEvidence(reviews[i]),
              onTap: () => controller.onReviewTap(reviews[i]),
            ),
          ],
        ],
        if (d.teamNow.isNotEmpty) ...[
          const SizedBox(height: KnSize.space24),
          _section(context, LangKeys.dashTeamNow.tr),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: d.teamNow.length,
              separatorBuilder: (_, _) => const SizedBox(width: KnSize.space8),
              itemBuilder: (_, i) => TeamMemberCard(member: d.teamNow[i], onTap: controller.onComingSoonTap),
            ),
          ),
        ],
      ],
    );
  }

  Widget _newCompany(BuildContext context) {
    final o = controller.data.value!.onboarding;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GetStartedCard(
          company: controller.companyName,
          teamInvited: o.teamInvited,
          jobCreated: o.firstJobCreated,
          onInvite: controller.onComingSoonTap,
          onCreateJob: controller.onNewJobTap,
        ),
        const SizedBox(height: KnSize.space16),
        _section(context, LangKeys.dashHowTitle.tr),
        const HowItWorksCard(),
        const SizedBox(height: 10),
        InfoRowCard(
          icon: LucideIcons.fileText,
          title: LangKeys.dashNoReports.tr,
          body: LangKeys.dashNoReportsBody.tr,
        ),
      ],
    );
  }
}
