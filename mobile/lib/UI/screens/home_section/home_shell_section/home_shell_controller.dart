import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import 'custom_widgets/capture_sheet.dart';

/// The app after login: bottom tabs and the camera button.
/// Technicians: Today, Me. Owners and managers: Home, Jobs, Reports, Profile.
class HomeShellController extends GetxController {
  HomeShellController({required this.session});

  final SessionService session;

  final RxInt index = 0.obs;

  bool get isManager => const {'owner', 'manager'}.contains(session.me.value?.role);

  void onTabTap(int i) => index.value = i;

  /// The camera button: a technician goes to the proof of the job in progress (M19). With no job going
  /// on it asks what to capture for (D-140): one of today's next jobs or a quick job; owners and managers
  /// get New job or the jobs list.
  void onCaptureTap() {
    final current = currentJob?.call();
    if (current != null) {
      Get.toNamed(RoutesConstants.captureHubScreen, arguments: JobArguments.of(current));
    } else {
      showCaptureSheet(this);
    }
  }

  /// Set by the shell binding: the technician's job in progress, from Today.
  JobListItemModel? Function()? currentJob;

  /// Set by the shell binding: the technician's next jobs today, from Today.
  List<JobListItemModel> Function()? nextJobs;

  /// Called after a quick job, so Today shows it.
  Future<void> Function()? reloadToday;

  /// Up to three of today's next jobs (technicians).
  List<JobListItemModel> get captureJobs => (nextJobs?.call() ?? const []).take(3).toList();

  /// "11:30 · AC not cooling"
  String jobLine(JobListItemModel j) {
    final at = j.scheduledAt;
    final when = at == null ? null : TimeUtils.clock(at, Get.locale?.languageCode ?? 'en');
    return [?when, j.title].join(' · ');
  }

  /// A next job: its page, where Start is.
  void onCaptureJobTap(JobListItemModel j) {
    Get.back<void>();
    Get.toNamed(RoutesConstants.jobDetailsScreen, arguments: JobArguments.of(j));
  }

  Future<void> onQuickJobTap() async {
    Get.back<void>();
    await Get.toNamed<void>(RoutesConstants.quickJobScreen);
    await reloadToday?.call();
  }

  /// Owners and managers: New job (M16).
  Future<void> onNewJobTap() async {
    Get.back<void>();
    await Get.toNamed<void>(RoutesConstants.newJobScreen);
  }

  /// Owners and managers: the Jobs tab.
  void onAllJobsTap() {
    Get.back<void>();
    index.value = 1;
  }
}
