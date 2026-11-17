import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../common_widgets/kn_glass_tab_bar.dart';
import '../../../theme/kn_app_theme.dart';
import '../../jobs_section/job_list_section/job_list_screen.dart';
import '../../me_section/me_section/me_tab.dart';
import '../../review_section/review_queue_section/review_queue_tab.dart';
import '../dashboard_section/dashboard_tab.dart';
import '../today_section/today_tab.dart';
import 'home_shell_controller.dart';

/// After login: the tabs and the floating tab bar with the camera button (Figma "Tab bar").
class HomeShellScreen extends GetView<HomeShellController> {
  const HomeShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = controller.isManager;
    final items = manager
        ? [
            KnTabItem(icon: LucideIcons.house, label: LangKeys.navHome.tr, key: const ValueKey('tab-home')),
            KnTabItem(icon: LucideIcons.briefcase, label: LangKeys.navJobs.tr, key: const ValueKey('tab-jobs')),
            KnTabItem(icon: LucideIcons.fileText, label: LangKeys.navReports.tr, key: const ValueKey('tab-reports')),
            KnTabItem(icon: LucideIcons.user, label: LangKeys.navProfile.tr, key: const ValueKey('tab-profile')),
          ]
        : [
            KnTabItem(icon: LucideIcons.house, label: LangKeys.navToday.tr, key: const ValueKey('tab-today')),
            KnTabItem(icon: LucideIcons.user, label: LangKeys.navMe.tr, key: const ValueKey('tab-me')),
          ];
    final tabs = manager
        ? [
            const DashboardTab(),
            const JobListScreen(asTab: true),
            const ReviewQueueTab(),
            const MeTab(),
          ]
        : [
            const TodayTab(),
            const MeTab(),
          ];
    return Scaffold(
      backgroundColor: context.kn.bgCanvas,
      body: Stack(
        children: [
          Positioned.fill(child: Obx(() => IndexedStack(index: controller.index.value, children: tabs))),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Obx(
              () => KnGlassTabBar(
                items: items,
                index: controller.index.value,
                onTap: controller.onTabTap,
                onCapture: controller.onCaptureTap,
                captureLabel: LangKeys.navCapture.tr,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
