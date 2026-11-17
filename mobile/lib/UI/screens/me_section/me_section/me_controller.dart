import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/customers_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/me_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/notifications_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_bottom_sheet.dart';
import '../../../common_widgets/kn_customer_search.dart';
import '../../../common_widgets/kn_toast.dart';
import '../../auth_section/profile_setup_section/profile_setup_controller.dart';

/// One number on the Me card ("14 Jobs done").
class MeStat {
  const MeStat(this.value, this.label);

  final int value;
  final String label;
}

/// M37 Me: who I am, my counts, and the way to my reports, things waiting to send, language and log out.
/// The same tab for owners and managers, with team counts instead of photos.
class MeController extends GetxController {
  MeController({
    required this.me,
    required this.session,
    required this.translation,
    this.queue,
    this.notifications,
  });

  final IMeApiRepository me;
  final SessionService session;
  final TranslationService translation;

  /// Photos, notes and answers still on this phone (technicians).
  final PhotoQueueService? queue;

  /// For the red count on Messages.
  final INotificationsApiRepository? notifications;

  final RxInt unread = 0.obs;

  final Rxn<MeStatsModel> stats = Rxn<MeStatsModel>();
  Worker? _sentWorker;

  @override
  void onInit() {
    super.onInit();
    load();
    final q = queue;
    if (q != null) _sentWorker = everAll([q.sent, q.notesSent, q.answersSent], (_) => load());
  }

  @override
  void onClose() {
    _sentWorker?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final results = await Future.wait([
      me.stats(),
      if (notifications != null) notifications!.list(limit: 1),
    ]);
    final s = results.first.dataOrNull as MeStatsModel?;
    if (s != null) stats.value = s;
    if (results.length > 1) {
      final list = results[1].dataOrNull as NotificationListModel?;
      if (list != null) unread.value = (list.meta.counts?['unread'] as num?)?.toInt() ?? 0;
    }
  }

  Future<void> onMessagesTap() async {
    await Get.toNamed(RoutesConstants.messagesScreen);
    load();
  }

  MeOutModel? get profile => session.me.value;

  bool get isManager => const {'owner', 'manager'}.contains(profile?.role);

  String get name => profile?.name ?? '';

  String get company => profile?.company?.name ?? '';

  String get role => switch (profile?.role) {
        'owner' => LangKeys.roleOwner.tr,
        'manager' => LangKeys.roleManager.tr,
        _ => LangKeys.roleTechnician.tr,
      };

  List<MeStat> get numbers {
    final s = stats.value;
    if (isManager) {
      return [
        MeStat(s?.reportsSent ?? 0, LangKeys.meReportsSent.tr),
        MeStat(s?.team ?? 0, LangKeys.meTeam.tr),
        MeStat(s?.toReview ?? 0, LangKeys.meToReview.tr),
      ];
    }
    return [
      MeStat(s?.jobsDone ?? 0, LangKeys.meJobsDone.tr),
      MeStat(s?.photos ?? 0, LangKeys.mePhotos.tr),
      MeStat(s?.reportsSent ?? 0, LangKeys.meReports.tr),
    ];
  }

  /// Everything still on this phone (the red badge, and the log-out warning).
  int get waiting => queue?.total ?? 0;

  String get languageName => TranslationService.byCode(translation.currentCode).nativeName;

  // ---- rows --------------------------------------------------------------------------------

  Future<void> onMyReportsTap() async {
    await Get.toNamed(RoutesConstants.myReportsScreen);
    load();
  }

  /// M39 Company settings (owners and managers; only owners change things).
  Future<void> onCompanySettingsTap() async {
    await Get.toNamed<void>(RoutesConstants.companySettingsScreen);
  }

  /// Customers: find one, then open their page (M18).
  Future<void> onCustomersTap() async {
    final finder = CustomerFinder(customers: Get.find<ICustomersApiRepository>())..startSearch();
    await showKnBottomSheet<void>(
      title: LangKeys.meCustomers.tr,
      child: KnCustomerSearchSheet(
        search: finder,
        onPicked: (c) {
          Get.back<void>();
          Get.toNamed<void>(RoutesConstants.customerScreen, arguments: CustomerArguments(id: c.id, name: c.name));
        },
      ),
    );
    finder.onClose();
  }

  /// M40 Team (owners and managers).
  Future<void> onTeamTap() async {
    await Get.toNamed(RoutesConstants.teamScreen);
    load();
  }

  /// Checklists and the builder (M26), for owners and managers.
  Future<void> onChecklistsTap() async {
    await Get.toNamed<void>(RoutesConstants.checklistLibraryScreen);
  }

  /// M45 Customer reviews (owners and managers).
  Future<void> onCustomerReviewsTap() async {
    await Get.toNamed<void>(RoutesConstants.companyReviewsScreen);
  }

  /// M44 My reviews.
  Future<void> onMyReviewsTap() async {
    await Get.toNamed<void>(RoutesConstants.myReviewsScreen);
  }

  Future<void> onWaitingTap() async {
    await Get.toNamed(RoutesConstants.waitingToSendScreen);
    load();
  }

  Future<void> onLanguageTap() async {
    await Get.toNamed(RoutesConstants.languageSettingsScreen);
    stats.refresh(); // the names on this tab follow the new language
  }

  Future<void> onEditTap() async {
    await Get.toNamed(RoutesConstants.profileSetupScreen, arguments: ProfileSetupController.editMode);
    session.me.refresh();
  }

  /// Help comes with its own step.
  void onComingSoonTap() => KnToast.info(LangKeys.commonComingSoon.tr);

  /// Log out now; the screen asks first when things are still waiting to send.
  Future<void> logout() async {
    await session.logout();
    Get.offAllNamed<void>(RoutesConstants.welcomeScreen);
  }
}
