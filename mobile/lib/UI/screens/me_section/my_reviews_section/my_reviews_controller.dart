import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reviews_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/review_words.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M44 My reviews: what customers said about my work this year, the average, the good tags,
/// and each review with the manager's reply.
class MyReviewsController extends GetxController {
  MyReviewsController({required this.reviews, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final IReviewsApiRepository reviews;
  final DateTime Function() _clock;

  /// The header shows this many tags.
  static const topTags = 3;

  final Rxn<MyReviewsModel> data = Rxn<MyReviewsModel>();
  final RxBool loading = true.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final result = await reviews.mine();
    loading.value = false;
    final d = result.dataOrNull;
    if (d == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    data.value = d;
  }

  // ---- what it shows -----------------------------------------------------------------------

  bool get empty => !loading.value && (data.value?.count ?? 0) == 0;

  List<ReviewListItemModel> get items => data.value?.data ?? const [];

  /// "4.8"
  String get average {
    final a = data.value?.average;
    return a == null ? '' : a.toStringAsFixed(1);
  }

  int get stars => (data.value?.average ?? 0).round();

  /// "36 reviews · 94% gave 4★ or more"
  String get summary =>
      LangKeys.myrevSummary.trParams({'n': '${data.value?.count ?? 0}', 'p': '${data.value?.share4Plus ?? 0}'});

  /// "On time · 31"
  List<String> get tags => (data.value?.tags ?? const <TagCountModel>[])
      .take(topTags)
      .map((t) => LangKeys.myrevTagCount.trParams({'label': ReviewWords.tag(t.key), 'n': '${t.count}'}))
      .toList();

  int rating(ReviewListItemModel r) => r.technicianRating ?? r.rating;

  String who(ReviewListItemModel r) => r.reviewerName ?? r.customer;

  /// "Green Valley Clinic · AC not cooling"
  String meta(ReviewListItemModel r) => [if (r.reviewerName != null) r.customer, r.jobTitle].join(' · ');

  String ago(ReviewListItemModel r) => ReviewWords.ago(r.createdAt, _clock());

  /// "Priya replied"
  String? replied(ReviewListItemModel r) {
    final a = r.reply?.author?.name;
    if (r.reply == null) return null;
    return LangKeys.myrevReplied.trParams({'name': a == null ? '' : TextUtils.firstName(a)}).trim();
  }

  // ---- actions -----------------------------------------------------------------------------

  Future<void> onReviewTap(ReviewListItemModel r) async {
    await Get.toNamed<void>(RoutesConstants.reviewDetailsScreen, arguments: r.id);
  }

  /// "See jobs to ask about": back to Today, where the jobs are.
  void onSeeJobsTap() => Get.offAllNamed<void>(RoutesConstants.homeScreen);
}
