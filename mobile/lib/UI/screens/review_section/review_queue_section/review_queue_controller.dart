import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reports_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_toast.dart';

enum QueueTab { review, approved, changes }

/// M30 Reports (owners and managers): reports waiting for review, oldest first; approved and sent
/// back ones on the other tabs.
class ReviewQueueController extends GetxController {
  ReviewQueueController({required this.reports, DateTime Function()? clock, this.searchDelay})
      : _clock = clock ?? DateTime.now;

  final IReportsApiRepository reports;
  final DateTime Function() _clock;
  final Duration? searchDelay;

  static const statuses = {
    QueueTab.review: ['pending_review'],
    QueueTab.approved: ['approved', 'shared', 'acknowledged'],
    QueueTab.changes: ['changes_requested'],
  };

  final Rx<QueueTab> tab = QueueTab.review.obs;
  final RxList<ReportListItemModel> items = <ReportListItemModel>[].obs;
  final RxMap<String, int> counts = <String, int>{}.obs;
  final RxInt approvedWeek = 0.obs;
  final RxBool loaded = false.obs;
  final RxBool searching = false.obs;
  final TextEditingController search = TextEditingController();
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    search.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final q = search.text.trim();
    final results = await Future.wait([
      reports.list(statuses: statuses[tab.value], q: q.isEmpty ? null : q),
      if (tab.value == QueueTab.review) reports.list(statuses: statuses[QueueTab.approved], period: 'week'),
    ]);
    loaded.value = true;
    final list = results.first.dataOrNull;
    if (list == null) {
      final e = results.first.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    items.assignAll(list.data);
    counts.assignAll({for (final e in (list.meta.counts ?? const {}).entries) e.key: (e.value as num).toInt()});
    if (results.length > 1) approvedWeek.value = results[1].dataOrNull?.data.length ?? approvedWeek.value;
  }

  int get waiting => counts['pending_review'] ?? 0;

  String get subtitle =>
      waiting == 0 ? LangKeys.queueSubtitleNone.tr : LangKeys.queueSubtitle.trParams({'n': '$waiting'});

  String tabLabel(QueueTab t) => switch (t) {
        QueueTab.review => LangKeys.queueToReview.trParams({'n': '$waiting'}),
        QueueTab.approved => LangKeys.queueApproved.tr,
        QueueTab.changes => LangKeys.queueChanges.tr,
      };

  void onTabTap(QueueTab t) {
    if (tab.value == t) return;
    tab.value = t;
    load();
  }

  void onSearchTap() {
    searching.toggle();
    if (!searching.value && search.text.isNotEmpty) {
      search.clear();
      load();
    }
  }

  void onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(searchDelay ?? const Duration(milliseconds: 350), load);
  }

  /// "10 min", "1 h", "2 days"
  String duration(int minutes) {
    if (minutes < 60) return LangKeys.queueMin.trParams({'n': '$minutes'});
    if (minutes < 60 * 24) return LangKeys.queueH.trParams({'n': '${minutes ~/ 60}'});
    return LangKeys.queueDays.trParams({'n': '${minutes ~/ (60 * 24)}'});
  }

  /// "just now", "10 min ago", "1 h ago", "2 days ago"
  String ago(DateTime? t) {
    if (t == null) return '';
    final m = _clock().difference(t.toLocal()).inMinutes;
    if (m < 1) return LangKeys.queueJustNow.tr;
    if (m < 60) return LangKeys.queueMinAgo.trParams({'n': '$m'});
    if (m < 60 * 24) return LangKeys.queueHAgo.trParams({'n': '${m ~/ 60}'});
    return LangKeys.queueDaysAgo.trParams({'n': '${m ~/ (60 * 24)}'});
  }

  String meta(ReportListItemModel r) => '${r.job.title} · #${r.number}';

  String byLine(ReportListItemModel r) => LangKeys.queueSentAgo.trParams({
        'name': (r.job.technician?.name ?? '').split(' ').first,
        'ago': ago(r.submittedAt ?? r.updatedAt),
      });

  /// The oldest waiting one is marked once it has waited an hour.
  String? waitChip(ReportListItemModel r) {
    final m = r.waitingMinutes;
    if (m == null) return null;
    final oldest = items.isNotEmpty && items.first.id == r.id && m >= 60;
    return oldest
        ? LangKeys.queueOldest.trParams({'time': duration(m)})
        : LangKeys.queueWaiting.trParams({'time': duration(m)});
  }

  bool isOldest(ReportListItemModel r) => (r.waitingMinutes ?? 0) >= 60 && items.isNotEmpty && items.first.id == r.id;

  Future<void> onOpen(ReportListItemModel r) async {
    await Get.toNamed(
      RoutesConstants.reportReviewScreen,
      arguments: ReportArguments(
        jobId: r.job.id,
        customer: r.job.customer,
        reportId: r.id,
        coverUrl: r.job.coverUrl,
        photos: r.job.photos ?? 0,
        thumbs: r.thumbs ?? const [],
      ),
    );
    load();
  }

  void onApprovedCardTap() => onTabTap(QueueTab.approved);
}
