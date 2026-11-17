import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/notifications_api_repository.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
import '../../jobs_section/job_list_section/job_list_controller.dart';
import '../../me_section/me_section/me_controller.dart';
import '../../review_section/review_queue_section/review_queue_controller.dart';
import '../dashboard_section/dashboard_controller.dart';
import '../today_section/today_controller.dart';
import 'home_shell_controller.dart';

class HomeShellBinding extends Bindings {
  @override
  void dependencies() {
    final shell = Get.put(HomeShellController(session: Get.find()));
    Get.lazyPut(
      () => MeController(
        me: Get.find(),
        session: Get.find(),
        translation: Get.find(),
        queue: Get.isRegistered<PhotoQueueService>() ? Get.find<PhotoQueueService>() : null,
        notifications: Get.find<INotificationsApiRepository>(),
      ),
    );
    if (shell.isManager) {
      Get.lazyPut(() => ReviewQueueController(reports: Get.find()));
      Get.lazyPut(
        () => DashboardController(
          repository: Get.find(),
          session: Get.find(),
          translation: Get.find(),
          onOpenTab: shell.onTabTap,
        ),
      );
      Get.lazyPut(() => JobListController(repository: Get.find(), session: Get.find(), translation: Get.find()));
    } else {
      Get.lazyPut(
        () => TodayController(repository: Get.find(), session: Get.find(), prefs: Get.find(), translation: Get.find()),
      );
      shell.currentJob = () => Get.isRegistered<TodayController>() ? Get.find<TodayController>().data.value?.currentJob : null;
    }
  }
}
