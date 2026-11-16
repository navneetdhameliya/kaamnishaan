import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/me_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

enum ReportFilter { all, waiting, changes, approved }

/// M30 My reports: this week's reports and where each one is — waiting for the manager, changes asked
/// (with the manager's words and a way to fix it), or approved.
class MyReportsController extends GetxController {
  MyReportsController({required this.me, required this.translation});

  final IMeApiRepository me;
  final TranslationService translation;

  final Rx<ReportFilter> filter = ReportFilter.all.obs;
  final RxList<ReportListItemModel> reports = <ReportListItemModel>[].obs;
  final RxMap<String, int> counts = <String, int>{}.obs;
  final RxBool loaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  static const _statuses = {
    ReportFilter.waiting: ['pending_review'],
    ReportFilter.changes: ['changes_requested'],
    ReportFilter.approved: ['approved', 'shared', 'acknowledged'],
  };

  Future<void> load() async {
    final result = await me.myReports(statuses: _statuses[filter.value]);
    loaded.value = true;
    final list = result.dataOrNull;
    if (list == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    reports.assignAll(list.data);
    counts.assignAll({for (final e in (list.meta.counts ?? const {}).entries) e.key: (e.value as num).toInt()});
  }

  void onFilterTap(ReportFilter f) {
    if (filter.value == f) return;
    filter.value = f;
    load();
  }

  int get total => counts['all'] ?? reports.length;

  String filterLabel(ReportFilter f) => switch (f) {
        ReportFilter.all => LangKeys.myreportsAll.trParams({'n': '$total'}),
        ReportFilter.waiting => LangKeys.myreportsWaiting.tr,
        ReportFilter.changes => LangKeys.myreportsChanges.tr,
        ReportFilter.approved => LangKeys.myreportsApproved.tr,
      };

  String meta(ReportListItemModel r) => LangKeys.myreportsMeta.trParams({'title': r.job.title, 'number': r.number});

  /// "Fri 30 Oct · 3:10 PM"
  String when(ReportListItemModel r) {
    final t = r.submittedAt ?? r.updatedAt;
    final day = DateFormat('EEE d MMM', translation.currentCode).format(t.toLocal());
    return '$day · ${TimeUtils.clock(t, translation.currentCode)}';
  }

  String statusText(ReportListItemModel r) => switch (r.status) {
        'pending_review' => LangKeys.reportWaitingReview.tr,
        'changes_requested' => LangKeys.reportChangesAsked.tr,
        'shared' || 'acknowledged' => LangKeys.myreportsApprovedSent.tr,
        'approved' => LangKeys.reportApproved.tr,
        _ => LangKeys.myreportsDraft.tr,
      };

  ReportArguments _args(ReportListItemModel r) => ReportArguments(
        jobId: r.job.id,
        customer: r.job.customer,
        reportId: r.id,
        coverUrl: r.job.coverUrl,
        photos: r.job.photos ?? 0,
      );

  Future<void> onOpen(ReportListItemModel r) async {
    await Get.toNamed(RoutesConstants.reportDraftScreen, arguments: _args(r));
    load();
  }

  /// Changes asked: back to the job's proof, where photos can be added and the report fixed.
  Future<void> onFixTap(ReportListItemModel r) async {
    await Get.toNamed(
      RoutesConstants.captureHubScreen,
      arguments: JobArguments(id: r.job.id, customer: r.job.customer, title: r.job.title),
    );
    load();
  }
}
