import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reviews_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/review_words.dart';
import '../../../common_widgets/kn_toast.dart';

/// M45 Low rating — follow up: what the customer said, "Call now" when they asked for a call, a
/// private note for the team, and "Mark as resolved".
class ReviewFollowupController extends GetxController {
  ReviewFollowupController({
    required this.reviews,
    CompanyReviewItemModel? review,
    DateTime Function()? clock,
    Future<bool> Function(Uri uri)? openUrl,
  })  : review = review ?? Get.arguments as CompanyReviewItemModel,
        _clock = clock ?? DateTime.now,
        _openUrl = openUrl ?? ((uri) => launchUrl(uri));

  final IReviewsApiRepository reviews;
  final CompanyReviewItemModel review;
  final DateTime Function() _clock;
  final Future<bool> Function(Uri uri) _openUrl;

  late final Rxn<FollowupOutModel> followup = Rxn<FollowupOutModel>(review.followup);
  late final TextEditingController note = TextEditingController(text: review.followup?.privateNote ?? '');
  final RxString noteDraft = ''.obs;
  final RxBool saving = false.obs;

  @override
  void onInit() {
    super.onInit();
    noteDraft.value = note.text;
    note.addListener(() => noteDraft.value = note.text);
  }

  @override
  void onClose() {
    note.dispose();
    super.onClose();
  }

  bool get resolved => followup.value?.status == 'resolved';

  /// The note changed since it was saved.
  bool get noteChanged => noteDraft.value.trim() != (followup.value?.privateNote ?? '').trim();

  /// "2-star review"
  String get title => LangKeys.crevNStar.trParams({'n': '${review.rating}'});

  /// "Needs follow-up · 25 min ago" or "Resolved · 1 h ago"
  String get subtitle {
    final done = followup.value?.resolvedAt;
    return resolved && done != null
        ? LangKeys.crevResolvedAgo.trParams({'ago': ReviewWords.ago(done, _clock())})
        : LangKeys.crevNeedsFollow.trParams({'ago': ReviewWords.ago(review.createdAt, _clock())});
  }

  /// "Mr. Mehta · Mehta house"
  String get who => [ReviewWords.who(review), if (review.reviewerName != null) review.customer].join(' · ');

  String? get quote {
    final c = review.comment?.trim();
    return c == null || c.isEmpty ? null : '“$c”';
  }

  List<String> get tags => review.tags.map(ReviewWords.tag).toList();

  /// "Carlos Ruiz · Report #R-1046"
  String get byLine => [
        if (review.technician != null) review.technician!.name,
        if (review.reportNumber != null) LangKeys.crevReportN.trParams({'n': review.reportNumber!}),
      ].join(' · ');

  /// "+91 98250 11111 · within 1 working day"
  String get callLine => [if (review.contactPhone != null) review.contactPhone!, LangKeys.crevCallWithin.tr].join(' · ');

  Future<void> onCallTap() async {
    final phone = review.contactPhone;
    if (phone == null) return KnToast.info(LangKeys.crevNoPhone.tr);
    await _openUrl(Uri(scheme: 'tel', path: phone));
  }

  /// A new visit starts from the customer's page.
  Future<void> onRevisitTap() async {
    await Get.toNamed<void>(
      RoutesConstants.customerScreen,
      arguments: CustomerArguments(id: review.customerId, name: review.customer),
    );
  }

  Future<void> onSaveNote() => _save(FollowupInModel(privateNote: note.text.trim()), LangKeys.crevNoteSaved.tr);

  Future<void> onResolveTap() => _save(
        FollowupInModel(
          status: resolved ? 'open' : 'resolved',
          privateNote: noteChanged ? note.text.trim() : null,
        ),
        resolved ? null : LangKeys.crevMarkedResolved.tr,
      );

  Future<void> _save(FollowupInModel body, String? done) async {
    if (saving.value) return;
    saving.value = true;
    final result = await reviews.followUp(review.id, body);
    saving.value = false;
    final f = result.dataOrNull;
    if (f == null) return KnToast.error(result.errorOrNull!.message);
    followup.value = f;
    if (done != null) KnToast.success(done);
  }
}
