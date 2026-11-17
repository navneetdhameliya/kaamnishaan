import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reviews_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/review_words.dart';
import '../../../common_widgets/kn_toast.dart';

enum RequestTone { plain, soon, good }

/// M45 Review requests: where each job's rating stands — Waiting, Rated, Opted out — and what
/// happens next.
class ReviewRequestsController extends GetxController {
  ReviewRequestsController({required this.reviews, required this.translation});

  final IReviewsApiRepository reviews;
  final TranslationService translation;

  static const tabs = ['waiting', 'rated', 'opted_out'];

  final RxString tab = 'waiting'.obs;
  final Rxn<RequestsPageModel> page = Rxn<RequestsPageModel>();
  final RxBool loading = true.obs;

  late final ReviewWords _words = ReviewWords(translation.currentCode);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    loading.value = true;
    final result = await reviews.requests(tab.value);
    loading.value = false;
    final d = result.dataOrNull;
    if (d == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    page.value = d;
  }

  Future<void> onTab(String t) async {
    if (t == tab.value) return;
    tab.value = t;
    page.value = null;
    await load();
  }

  List<RequestItemModel> get items => page.value?.data ?? const [];

  String label(String t) {
    final c = page.value?.counts;
    return switch (t) {
      'rated' => LangKeys.rreqRated.trParams({'n': '${c?.rated ?? 0}'}),
      'opted_out' => LangKeys.rreqOptedOut.trParams({'n': '${c?.optedOut ?? 0}'}),
      _ => LangKeys.rreqWaiting.trParams({'n': '${c?.waiting ?? 0}'}),
    };
  }

  String chip(RequestItemModel r) => ReviewWords.requestChip(r);

  String line(RequestItemModel r) => _words.requestLine(r);

  RequestTone tone(RequestItemModel r) => switch (r.status) {
        'rated' => RequestTone.good,
        'ai_call_scheduled' || 'ai_call_done' => RequestTone.soon,
        _ => RequestTone.plain,
      };

  Future<void> onTap(RequestItemModel r) async {
    await Get.toNamed<void>(RoutesConstants.jobDetailsScreen, arguments: JobArguments(id: r.jobId, customer: r.customer));
    await load();
  }
}
