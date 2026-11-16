import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/home_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// What the week line under "38 reports sent" says.
enum WeekTrend { more, less, same, first, none }

/// M13 Dashboard for owners and managers: this week, today's numbers, reports to review and the team.
/// A new company (team not invited or no job yet) sees "Get started" instead (Figma 42:901).
class DashboardController extends GetxController {
  DashboardController({
    required this.repository,
    required this.session,
    required this.translation,
    this.onOpenTab,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final IHomeApiRepository repository;
  final SessionService session;
  final TranslationService translation;

  /// Switches the bottom tab (1 Jobs, 2 Reports) when a number is tapped.
  final void Function(int tab)? onOpenTab;
  final DateTime Function() _clock;

  final Rxn<DashboardModel> data = Rxn<DashboardModel>();
  final RxList<ReportListItemModel> reviews = <ReportListItemModel>[].obs;
  final RxBool loading = false.obs;

  static const reviewRows = 2;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  String get name => session.me.value?.name ?? '';
  String get firstName => TextUtils.firstName(name);
  String get initials => TextUtils.initials(name);
  String? get avatarUrl => session.me.value?.avatarUrl;
  String get companyName => session.me.value?.company?.name ?? '';

  String get roleLabel =>
      session.me.value?.role == 'owner' ? LangKeys.roleOwner.tr : LangKeys.roleManager.tr;

  bool get isNewCompany {
    final o = data.value?.onboarding;
    return o != null && !(o.teamInvited && o.firstJobCreated);
  }

  int get stepsDone {
    final o = data.value?.onboarding;
    if (o == null) return 1;
    return 1 + (o.teamInvited ? 1 : 0) + (o.firstJobCreated ? 1 : 0);
  }

  String get greeting => '${TimeUtils.greeting(_clock())},';

  int todayCount(String key) => (data.value?.today[key] as num?)?.toInt() ?? 0;

  WeekTrend get trend {
    final d = data.value;
    if (d == null || (d.reportsWeek == 0 && d.reportsLastWeek == 0)) return WeekTrend.none;
    if (d.reportsLastWeek == 0) return WeekTrend.first;
    if (d.reportsWeek == d.reportsLastWeek) return WeekTrend.same;
    return d.reportsWeek > d.reportsLastWeek ? WeekTrend.more : WeekTrend.less;
  }

  String get trendText {
    final d = data.value;
    if (d == null) return '';
    final pct = d.reportsLastWeek == 0
        ? 0
        : ((d.reportsWeek - d.reportsLastWeek).abs() * 100 / d.reportsLastWeek).round();
    return switch (trend) {
      WeekTrend.more => LangKeys.dashMore.trParams({'pct': '$pct'}),
      WeekTrend.less => LangKeys.dashLess.trParams({'pct': '$pct'}),
      WeekTrend.same => LangKeys.dashSame.tr,
      WeekTrend.first => LangKeys.dashFirst.tr,
      WeekTrend.none => '',
    };
  }

  /// "Ramesh · 10 min ago"
  String reviewMeta(ReportListItemModel r) {
    final who = r.job.technician?.name ?? '';
    final when = r.submittedAt == null ? '' : TimeUtils.ago(r.submittedAt!, _clock());
    return [who, when].where((s) => s.isNotEmpty).join(' · ');
  }

  /// "6 photos · AI draft"
  String reviewEvidence(ReportListItemModel r) {
    final photos = LangKeys.dashPhotos.trParams({'count': '${r.job.photos ?? 0}'});
    return r.draftedBy == 'ai' ? '$photos · ${LangKeys.dashAiDraft.tr}' : photos;
  }

  Future<void> load() async {
    loading.value = data.value == null;
    final (dashResult, queueResult) =
        await (repository.dashboard(), repository.reviewQueue(limit: reviewRows)).wait;
    loading.value = false;
    final dash = dashResult.dataOrNull;
    final queue = queueResult.dataOrNull;
    if (dash != null) data.value = dash;
    if (queue != null) reviews.assignAll(queue.data);
    final error = dashResult.errorOrNull ?? queueResult.errorOrNull;
    if (error != null && !error.isNetwork) KnToast.error(error.message);
  }

  void onReviewTilesTap() => onOpenTab?.call(2);

  void onJobTilesTap() => onOpenTab?.call(1);

  /// Review, team and job screens come in the next steps.
  void onComingSoonTap() => KnToast.info(LangKeys.commonComingSoon.tr);
}
