import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_text_link.dart';
import '../../../commons/behaviour/behaviour.dart';
import '../../../commons/text_widgets/base/custom_base_text_widget.dart';
import '../../../theme/kn_app_theme.dart';
import '../../../theme/kn_tokens.g.dart';
import '../home_shell_section/custom_widgets/home_header.dart';
import 'custom_widgets/job_row_card.dart';
import 'custom_widgets/now_job_card.dart';
import 'custom_widgets/today_empty.dart';
import 'custom_widgets/today_stats.dart';
import 'today_controller.dart';

/// M12 Today (Figma 19:858; empty 19:973; offline 19:1058; loading 20:977).
class TodayTab extends GetView<TodayController> {
  const TodayTab({super.key});

  /// Design header is 248 tall with a 32 px status bar; cards start 56 px above its end.
  static const _headerHeight = 216.0;
  static const _contentTop = 160.0;

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
              final loading = controller.loading.value && data == null;
              return Stack(
                children: [
                  HomeHeader(
                    top: top,
                    height: _headerHeight,
                    greeting: controller.greetingLine,
                    name: controller.firstName,
                    initials: controller.initials,
                    avatarUrl: controller.avatarUrl,
                    unread: (data?.unread ?? 0) > 0,
                    onBell: controller.onJobTap,
                    child: Padding(
                      padding: const EdgeInsets.only(top: KnSize.space16),
                      child: TodayStats(
                        jobs: data?.stats.jobs ?? 0,
                        done: data?.stats.done ?? 0,
                        photos: data?.stats.photos ?? 0,
                        loading: loading,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(KnSize.space16, top + _contentTop, KnSize.space16, 112),
                    child: _content(context, loading),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, bool loading) {
    final kn = context.kn;
    final text = context.knText;
    final data = controller.data.value;
    final offline = controller.offline.value;
    final children = <Widget>[
      if (offline) ...[
        Container(
          key: const ValueKey('offline-banner'),
          padding: const EdgeInsets.symmetric(horizontal: KnSize.space16, vertical: 6),
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(color: kn.borderDefault, borderRadius: BorderRadius.circular(KnSize.radiusMd)),
          child: Row(
            children: [
              Icon(LucideIcons.cloudOff, size: 20, color: kn.textSecondary),
              const SizedBox(width: KnSize.space12),
              Expanded(
                child: CustomBaseTextWidget(LangKeys.commonOfflineSaved.tr, style: text.labelSm, color: kn.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: KnSize.space12),
      ],
    ];
    if (loading) return Column(children: [...children, const TodaySkeleton()]);
    if (data == null) return Column(children: children);
    if (controller.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...children,
          TodayEmpty(
            onRefresh: controller.load,
            managerName: data.manager?.name,
            onCallManager: controller.onCallManagerTap,
          ),
        ],
      );
    }
    final current = data.currentJob;
    final next = controller.nextUp;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        if (current != null) ...[
          NowJobCard(
            job: current,
            time: controller.timeOf(current.scheduledAt),
            offline: offline,
            onContinue: () => controller.onJobTap(current),
          ),
          const SizedBox(height: KnSize.space16),
        ],
        if (next.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: CustomBaseTextWidget(LangKeys.todayNextUp.tr, style: text.h3)),
              KnTextLink(key: const ValueKey('see-all'), text: LangKeys.commonSeeAll.tr, large: true, onTap: controller.onJobTap),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < next.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            JobRowCard(
              job: next[i],
              time: controller.timeOf(next[i].scheduledAt),
              onTap: () => controller.onJobTap(next[i]),
            ),
          ],
        ],
      ],
    );
  }
}
