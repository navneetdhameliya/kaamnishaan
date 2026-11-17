import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/jobs_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reports_api_repository.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reviews_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/review_words.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M31 Report sent to manager: what was sent and who checks it next. When the customer can be asked for a
/// review, it offers that first (Figma 273:2374).
class ReportSentController extends GetxController {
  ReportSentController({
    required this.reports,
    required this.translation,
    this.jobs,
    this.reviews,
    ReportArguments? args,
  }) : args = args ?? Get.arguments as ReportArguments;

  final IReportsApiRepository reports;
  final TranslationService translation;
  final IJobsApiRepository? jobs;
  final IReviewsApiRepository? reviews;
  final ReportArguments args;

  final Rxn<ReportOutModel> report = Rxn<ReportOutModel>();

  /// The job's review card; the ask shows while it is "not asked yet" and allowed.
  final Rxn<JobReviewModel> review = Rxn<JobReviewModel>();
  final RxBool dismissed = false.obs;
  final RxBool asking = false.obs;

  late final ReviewWords words = ReviewWords(translation.currentCode);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final repo = jobs;
    final results = await Future.wait([
      reports.report(args.reportId!),
      if (repo != null) repo.job(args.jobId),
    ]);
    report.value = results.first.dataOrNull as ReportOutModel?;
    if (results.length > 1) review.value = (results[1].dataOrNull as JobOutModel?)?.review;
  }

  // ---- ask for a review --------------------------------------------------------------------

  bool get canAsk {
    final r = review.value;
    return !dismissed.value && r != null && r.status == 'not_requested' && r.canRequest;
  }

  String get askTitle => LangKeys.askTitle.trParams({'name': words.contact(review.value!)});

  /// "Green Valley Clinic · +1 555 010 0444"
  String get askLine => [args.customer, review.value?.contactPhone].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

  bool get aiCall => review.value?.aiCallEnabled ?? true;

  void onNotNowTap() => dismissed.value = true;

  Future<void> onAskTap() async {
    final repo = reviews;
    if (repo == null || asking.value) return;
    asking.value = true;
    final result = await repo.request(args.jobId);
    asking.value = false;
    final card = result.dataOrNull;
    if (card == null) return KnToast.error(result.errorOrNull!.message);
    review.value = card;
    KnToast.success(
      card.status == 'queued' ? LangKeys.reviewAskedQueued.tr : LangKeys.reviewAskedSent.trParams({'name': words.contact(card)}),
    );
  }

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
