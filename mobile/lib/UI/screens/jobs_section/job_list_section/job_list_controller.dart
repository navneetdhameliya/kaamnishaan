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

/// The filters sheet's job states: each is one or more server states (D-139).
enum JobState { waiting, going, toCheck, done, cancelled }

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

  /// The filters sheet: a state and (managers) a technician; drafts while the sheet is open.
  final Rxn<JobState> state = Rxn<JobState>();
  final RxnString technicianId = RxnString();
  final RxnString technicianName = RxnString();
  final Rxn<JobState> draftState = Rxn<JobState>();
  final RxnString draftTechnician = RxnString();
  final RxList<AssignableTechnicianModel> technicians = <AssignableTechnicianModel>[].obs;

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

  static List<String> statesOf(JobState? s) => switch (s) {
        null => const [],
        JobState.waiting => const ['unassigned', 'assigned'],
        JobState.going => const ['in_progress', 'changes_requested'],
        JobState.toCheck => const ['in_review'],
        JobState.done => const ['completed'],
        JobState.cancelled => const ['cancelled'],
      };

  JobQuery get query {
    final st = statesOf(state.value);
    final who = technicianId.value;
    return switch (filter.value) {
      JobFilter.today => JobQuery(date: _today, search: search.value, statuses: st, assignee: who),
      JobFilter.tomorrow =>
        JobQuery(date: _today.add(const Duration(days: 1)), search: search.value, statuses: st, assignee: who),
      JobFilter.unassigned =>
        JobQuery(date: _today, range: 'week', unassigned: true, search: search.value, statuses: st),
    };
  }

  String stateLabel(JobState s) => switch (s) {
        JobState.waiting => LangKeys.jfWaiting.tr,
        JobState.going => LangKeys.jfGoing.tr,
        JobState.toCheck => LangKeys.jfToCheck.tr,
        JobState.done => LangKeys.jfDone.tr,
        JobState.cancelled => LangKeys.jfCancelled.tr,
      };

  /// How many sheet filters are on (the dot on the filters button).
  int get sheetFilters => (state.value == null ? 0 : 1) + (technicianId.value == null ? 0 : 1);

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

  bool get hasFilters => filter.value != JobFilter.today || search.value.trim().isNotEmpty || sheetFilters > 0;

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
    state.value = null;
    technicianId.value = null;
    technicianName.value = null;
    load();
  }

  /// M15; the list loads again when the office changed the job there (assigned, cancelled, deleted).
  Future<void> onJobTap(JobListItemModel job) async {
    final changed = await Get.toNamed<bool>(RoutesConstants.jobDetailsScreen, arguments: JobArguments.of(job));
    if (changed == true) await load();
  }

  // ---- the filters sheet -------------------------------------------------------------------

  /// Opens with the filters in use; managers also get their technicians to pick from.
  Future<void> startFilters() async {
    draftState.value = state.value;
    draftTechnician.value = technicianId.value;
    if (isManager && technicians.isEmpty) {
      final result = await repository.technicians();
      final list = result.dataOrNull?.data;
      if (list != null) technicians.assignAll(list.where((t) => t.status != 'invited'));
    }
  }

  void onDraftState(JobState? s) => draftState.value = draftState.value == s ? null : s;

  void onDraftTechnician(String? id) => draftTechnician.value = draftTechnician.value == id ? null : id;

  void onApplyFilters() {
    state.value = draftState.value;
    technicianId.value = draftTechnician.value;
    technicianName.value = technicians.firstWhereOrNull((t) => t.id == draftTechnician.value)?.name;
    load();
  }

  void onResetDraft() {
    draftState.value = null;
    draftTechnician.value = null;
  }

  /// M16 New job; the list (or dashboard) loads again when a job was made.
  Future<void> onNewJobTap() async {
    final made = await Get.toNamed(RoutesConstants.newJobScreen);
    if (made == true) await load();
  }


  @override
  void onClose() {
    _debounce?.cancel();
    searchController.dispose();
    super.onClose();
  }
}
