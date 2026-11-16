import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reports_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/time_utils.dart';

/// M31 Report sent to manager: what was sent and who checks it next.
class ReportSentController extends GetxController {
  ReportSentController({required this.reports, required this.translation, ReportArguments? args})
      : args = args ?? Get.arguments as ReportArguments;

  final IReportsApiRepository reports;
  final TranslationService translation;
  final ReportArguments args;

  final Rxn<ReportOutModel> report = Rxn<ReportOutModel>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async => report.value = (await reports.report(args.reportId!)).dataOrNull;

  int get photos {
    final p = report.value?.evidence.photos;
    if (p == null) return args.photos;
    return p.values.fold<int>(0, (n, v) => n + ((v as num?)?.toInt() ?? 0));
  }

  String get meta => LangKeys.sentMeta.trParams({'number': report.value?.number ?? '', 'n': '$photos'});

  String get sentAt {
    final t = report.value?.submittedAt ?? DateTime.now();
    return LangKeys.sentAt.trParams({'time': TimeUtils.clock(t, translation.currentCode)});
  }

  String? get cover => report.value?.job.coverUrl ?? args.coverUrl;

  void onBackTodayTap() => Get.offAllNamed<void>(RoutesConstants.homeScreen);

  void onSeeReportTap() => Get.offNamed<void>(RoutesConstants.reportDraftScreen, arguments: args);
}
