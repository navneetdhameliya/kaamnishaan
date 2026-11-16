import 'dart:async';

import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reports_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_toast.dart';

enum MakePhase { working, failed }

enum RowState { waiting, running, done }

/// One line of "Making your report…".
class MakeRow {
  const MakeRow(this.text, this.state);

  final String text;
  final RowState state;
}

/// M31 Making your report: asks the server to write the draft and follows its steps
/// (collect evidence → write → check for missing proof). When it is done the draft opens; when it
/// fails nothing is lost and the technician can try again.
class ReportMakingController extends GetxController {
  ReportMakingController({
    required this.reports,
    ReportArguments? args,
    this.pollEvery = const Duration(milliseconds: 1200),
    this.autoStart = true,
  }) : args = args ?? Get.arguments as ReportArguments;

  final IReportsApiRepository reports;
  final ReportArguments args;
  final Duration pollEvery;
  final bool autoStart;

  static const stepKeys = ['collect_evidence', 'write_report', 'check_evidence'];

  final Rx<MakePhase> phase = MakePhase.working.obs;
  final RxMap<String, String> steps = <String, String>{}.obs;
  final RxnString reportId = RxnString();
  Timer? _timer;
  String? _taskId;

  @override
  void onInit() {
    super.onInit();
    reportId.value = args.reportId;
    if (autoStart) start();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> start() async {
    phase.value = MakePhase.working;
    steps.clear();
    final result = await reports.start(args.jobId);
    final started = result.dataOrNull;
    if (started == null) {
      final e = result.errorOrNull!;
      // already sent for review: show it
      if (e.code == 'report_already_submitted' && reportId.value != null) return _openDraft();
      phase.value = MakePhase.failed;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    reportId.value = started.reportId;
    _taskId = started.taskId;
    if (started.status == 'draft') return _openDraft();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(pollEvery, check);
  }

  /// Asks how far it is; a lost connection just asks again.
  Future<void> check() async {
    final id = _taskId;
    if (id == null) return;
    final task = (await reports.task(id)).dataOrNull;
    if (task == null) return _schedule();
    steps.assignAll({for (final s in task.steps) s.key: s.status});
    switch (task.status) {
      case 'done':
        await _openDraft();
      case 'failed':
        phase.value = MakePhase.failed;
      default:
        _schedule();
    }
  }

  Future<void> _openDraft() async {
    _timer?.cancel();
    await Get.offNamed(RoutesConstants.reportDraftScreen, arguments: args.withReport(reportId.value!));
  }

  RowState _state(String key) => switch (steps[key]) {
        'done' => RowState.done,
        'running' => RowState.running,
        _ => RowState.waiting,
      };

  /// The lines shown: photos and checklists are read first, then the notes are written up, then the check.
  List<MakeRow> get rows => [
        MakeRow(LangKeys.reportStepPhotos.trParams({'n': '${args.photos}'}), _state('collect_evidence')),
        if (args.checklists > 0)
          MakeRow(LangKeys.reportStepChecklists.trParams({'n': '${args.checklists}'}), _state('collect_evidence')),
        MakeRow(
          args.notes > 0 ? LangKeys.reportStepNotes.trParams({'n': '${args.notes}'}) : LangKeys.reportStepWrite.tr,
          _state('write_report'),
        ),
        MakeRow(LangKeys.reportStepMissing.tr, _state('check_evidence')),
      ];

  /// 0 to 1; a running step counts half.
  double get progress {
    var p = 0.0;
    for (final k in stepKeys) {
      p += switch (_state(k)) { RowState.done => 1, RowState.running => 0.5, RowState.waiting => 0 };
    }
    return p / stepKeys.length;
  }

  void onBackTap() => Get.back<void>();
}
