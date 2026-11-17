import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/data_access_layer/api_repository/reviews_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/review_words.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M44 Review details: the before and after photos, the customer's stars for the service and for the
/// technician, their words and tags, and the manager's reply.
class ReviewDetailsController extends GetxController {
  ReviewDetailsController({
    required this.reviews,
    required this.translation,
    String? reviewId,
    DateTime Function()? clock,
  })  : reviewId = reviewId ?? Get.arguments as String,
        _clock = clock ?? DateTime.now;

  final IReviewsApiRepository reviews;
  final TranslationService translation;
  final String reviewId;
  final DateTime Function() _clock;

  final Rxn<ReviewOutModel> review = Rxn<ReviewOutModel>();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final result = await reviews.review(reviewId);
    final r = result.dataOrNull;
    if (r == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    review.value = r;
  }

  String get subtitle {
    final n = review.value?.reportNumber;
    return n == null ? '' : LangKeys.rdSubtitle.trParams({'n': n});
  }

  String get name => review.value?.reviewerName ?? review.value?.customer ?? '';

  /// "Green Valley Clinic · 31 Oct"
  String get meta {
    final r = review.value;
    if (r == null) return '';
    return [
      if (r.reviewerName != null) r.customer,
      DateFormat('d MMM', translation.currentCode).format(r.createdAt.toLocal()),
    ].join(' · ');
  }

  /// "You (Ramesh)"
  String get youLabel => LangKeys.rdYou.trParams({'name': TextUtils.firstName(review.value?.technician?.name ?? '')});

  String? get quote {
    final c = review.value?.comment?.trim();
    return c == null || c.isEmpty ? null : '“$c”';
  }

  List<String> get tags => (review.value?.tags ?? const <String>[]).map(ReviewWords.tag).toList();

  /// "Priya Mehta replied · 1 h ago"
  String? get replyBy {
    final rp = review.value?.reply;
    if (rp == null) return null;
    return LangKeys.rdRepliedAgo.trParams({
      'name': rp.author?.name ?? '',
      'ago': ReviewWords.ago(rp.createdAt, _clock()),
    });
  }
}
