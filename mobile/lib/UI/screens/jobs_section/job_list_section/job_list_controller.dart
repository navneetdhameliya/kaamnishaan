import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

enum JobFilter { today, tomorrow, unassigned }

/// M14 Job list: today, tomorrow or unassigned (this week), with search by customer or address.
/// Owners and managers see everyone's jobs; technicians see their own (the server decides).
class JobListController extends GetxController {
  JobListController({
    required this.repository,
    required this.session,
    required this.translation,
    DateTime Function()? clock,
    this.searchDelay = const Duration(milliseconds: 400),
  }) : _clock = clock ?? DateTime.now;

  final IJobsApiRepository repository;
  final SessionService session;
  final TranslationService translation;
  final DateTime Function() _clock;
  final Duration searchDelay;

  final TextEditingController searchController = TextEditingController();
  final Rx<JobFilter> filter = JobFilter.today.obs;
  final RxString search = ''.obs;
  final RxList<JobListItemModel> jobs = <JobListItemModel>[].obs;
  final RxBool loading = false.obs;
  final RxBool loaded = false.obs;
  Timer? _debounce;
  int _request = 0;

  bool get isManager => const {'owner', 'manager'}.contains(session.me.value?.role);

  List<JobFilter> get filters => isManager ? JobFilter.values : const [JobFilter.today, JobFilter.tomorrow];

  @override
  void onInit() {
    super.onInit();
    load();
  }

  DateTime get _today {
    final n = _clock();
    return DateTime(n.year, n.month, n.day);
  }

  JobQuery get query => switch (filter.value) {
        JobFilter.today => JobQuery(date: _today, search: search.value),
        JobFilter.tomorrow => JobQuery(date: _today.add(const Duration(days: 1)), search: search.value),
        JobFilter.unassigned => JobQuery(date: _today, range: 'week', unassigned: true, search: search.value),
      };

  String chipLabel(JobFilter f) => switch (f) {
        JobFilter.today => LangKeys.jobsToday.tr,
        JobFilter.tomorrow => LangKeys.jobsTomorrow.tr,
        JobFilter.unassigned => LangKeys.jobsUnassigned.tr,
      };

  /// "Sat, 31 Oct · 6 jobs today", "Sun, 1 Nov · 3 jobs", "This week · 0 found"
  String get subtitle {
    final n = '${jobs.length}';
    final locale = translation.currentCode;
    return switch (filter.value) {
      JobFilter.today when search.value.trim().isEmpty =>
        LangKeys.jobsCountToday.trParams({'date': DateFormat('EEE, d MMM', locale).format(_today), 'count': n}),
      JobFilter.today || JobFilter.tomorrow => LangKeys.jobsCountDay.trParams({
          'date': DateFormat('EEE, d MMM', locale)
              .format(filter.value == JobFilter.today ? _today : _today.add(const Duration(days: 1))),
          'count': n,
        }),
      JobFilter.unassigned => LangKeys.jobsCountWeek.trParams({'count': n}),
    };
  }

  /// "Ramesh" under each job, only for managers.
  bool get showAssignee => isManager;

  String timeOf(DateTime? t) => t == null ? '' : TimeUtils.clock(t, translation.currentCode);

  bool get hasFilters => filter.value != JobFilter.today || search.value.trim().isNotEmpty;

  Future<void> load() async {
    final request = ++_request;
    loading.value = true;
    final result = await repository.list(query);
    if (request != _request) return; // a newer search is on its way
    loading.value = false;
    loaded.value = true;
    final data = result.dataOrNull;
    if (data != null) {
      jobs.assignAll(data.data);
    } else if (!result.errorOrNull!.isNetwork) {
      KnToast.error(result.errorOrNull!.message);
    }
  }

  void onFilterTap(JobFilter f) {
    if (filter.value == f) return;
    filter.value = f;
    load();
  }

  void onSearchChanged(String value) {
    search.value = value;
    _debounce?.cancel();
    _debounce = Timer(searchDelay, load);
  }

  void onClearSearchTap() {
    searchController.clear();
    onSearchChanged('');
  }

  void onClearFiltersTap() {
    _debounce?.cancel();
    searchController.clear();
    search.value = '';
    filter.value = JobFilter.today;
    load();
  }

  void onJobTap(JobListItemModel job) =>
      Get.toNamed(RoutesConstants.jobDetailsScreen, arguments: JobArguments.of(job));

  /// Filters sheet and new job (M16) come with the job editing step.
  /// M16 New job; the list (or dashboard) loads again when a job was made.
  Future<void> onNewJobTap() async {
    final made = await Get.toNamed(RoutesConstants.newJobScreen);
    if (made == true) await load();
  }

  void onComingSoonTap() => KnToast.info(LangKeys.commonComingSoon.tr);

  @override
  void onClose() {
    _debounce?.cancel();
    searchController.dispose();
    super.onClose();
  }
}
