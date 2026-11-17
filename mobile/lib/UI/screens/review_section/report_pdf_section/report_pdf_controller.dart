import 'dart:async';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reports_api_repository.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/photo_pairs.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M34 Report PDF: waits while the server builds it, then shows the first page and offers Download
/// and Share. The page shown is drawn from the report itself; the file is the server's PDF (D-73).
class ReportPdfController extends GetxController {
  ReportPdfController({
    required this.reports,
    required this.jobs,
    required this.session,
    required this.translation,
    ReportArguments? args,
    this.pollEvery = const Duration(seconds: 2),
    Future<bool> Function(Uri)? open,
  })  : args = args ?? Get.arguments as ReportArguments,
        _open = open ?? ((u) => launchUrl(u, mode: LaunchMode.externalApplication));

  final IReportsApiRepository reports;
  final IJobsApiRepository jobs;
  final SessionService session;
  final TranslationService translation;
  final ReportArguments args;
  final Duration pollEvery;
  final Future<bool> Function(Uri) _open;

  final Rxn<PdfOutModel> pdf = Rxn<PdfOutModel>();
  final Rxn<ReportOutModel> report = Rxn<ReportOutModel>();
  final Rx<ChosenPair> pair = const ChosenPair().obs;
  Timer? _timer;

  String get reportId => args.reportId!;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    final results = await Future.wait([reports.report(reportId), jobs.evidence(args.jobId)]);
    report.value = results[0].dataOrNull as ReportOutModel? ?? report.value;
    final list = results[1].dataOrNull as EvidenceListModel?;
    if (list != null) pair.value = ChosenPair.pick(list);
    await check();
  }

  /// Asks for the PDF; while it is building, asks again.
  Future<void> check() async {
    _timer?.cancel();
    final result = await reports.pdf(reportId);
    final p = result.dataOrNull;
    if (p == null) {
      if (!result.errorOrNull!.isNetwork) KnToast.error(result.errorOrNull!.message);
      _timer = Timer(pollEvery, check);
      return;
    }
    pdf.value = p;
    if (p.status == 'building') _timer = Timer(pollEvery, check);
  }

  bool get building => pdf.value == null || pdf.value!.status == 'building';

  bool get failed => pdf.value?.status == 'failed';

  bool get ready => pdf.value?.status == 'ready';

  int get pages => pdf.value?.pages ?? 1;

  String get number => report.value?.number ?? '';

  String get company => session.me.value?.company?.name ?? '';

  String? get logo => session.me.value?.company?.logoUrl;

  String get customer => report.value?.job.customer ?? args.customer;

  String get technician => report.value?.job.technician?.name ?? '';

  String _day(DateTime t) => DateFormat('d MMM y', translation.currentCode).format(t.toLocal());

  /// "31 Oct 2026"
  String get date => _day(report.value?.approvedAt ?? report.value?.updatedAt ?? DateTime.now());

  /// "Sat 31 Oct · 11:30 AM"
  String get workedAt {
    final t = report.value?.submittedAt ?? report.value?.updatedAt;
    if (t == null) return '';
    return '${DateFormat('EEE d MMM', translation.currentCode).format(t.toLocal())} · '
        '${TimeUtils.clock(t, translation.currentCode)}';
  }

  String? get approvedBy => report.value?.approvedBy?.name;

  int get checksPassed => report.value?.evidence.checksPassed ?? 0;

  int get checksTotal => checksPassed + (report.value?.evidence.checksFailed ?? 0);

  Future<void> onTryAgainTap() async {
    pdf.value = null;
    await check();
  }

  Future<void> onDownloadTap() async {
    final url = pdf.value?.url;
    if (url == null) return;
    await _open(Uri.parse(url));
  }

  void onShareTap() => Get.toNamed(RoutesConstants.shareReportScreen, arguments: args);
}
