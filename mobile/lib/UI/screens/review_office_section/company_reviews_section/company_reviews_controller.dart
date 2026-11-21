import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/reviews_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/review_words.dart';
import '../../../../infrastructure/shared/text_utils.dart';
import '../../../common_widgets/kn_dictation.dart';
import '../../../common_widgets/kn_toast.dart';

/// M45 Customer reviews (owners and managers): the average, how many of each star, the chips
/// All / Needs reply / Low, and each review with a reply or a follow-up.
class CompanyReviewsController extends GetxController {
  CompanyReviewsController({
    required this.reviews,
    required this.dictation,
    String? filter,
    DateTime Function()? clock,
  })
      : _clock = clock ?? DateTime.now {
    this.filter.value = filter ?? (Get.arguments is String ? Get.arguments as String : 'all');
  }

  final IReviewsApiRepository reviews;

  /// Speak instead of typing (the microphone in the text box).
  final Dictation dictation;
  final DateTime Function() _clock;

  static const filters = ['all', 'needs_reply', 'low'];

  final RxString filter = 'all'.obs;
  final Rxn<ReviewsPageModel> page = Rxn<ReviewsPageModel>();
  final RxBool loading = true.obs;

  // the reply sheet
  final TextEditingController replyText = TextEditingController();
  final RxBool sending = false.obs;
  final RxBool suggesting = false.obs;
  final RxString draft = ''.obs;

  @override
  void onInit() {
    super.onInit();
    replyText.addListener(() => draft.value = replyText.text);
    load();
  }

  @override
  void onClose() {
    dictation.cancel();
    replyText.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final result = await reviews.company(filter.value);
    loading.value = false;
    final d = result.dataOrNull;
    if (d == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    page.value = d;
  }

  Future<void> onFilter(String f) async {
    if (f == filter.value) return;
    filter.value = f;
    await load();
  }

  // ---- what it shows -----------------------------------------------------------------------

  bool get empty => !loading.value && (page.value?.count ?? 0) == 0;

  List<CompanyReviewItemModel> get items => page.value?.data ?? const [];

  /// "4.7"
  String get average {
    final a = page.value?.average;
    return a == null ? '–' : a.toStringAsFixed(1);
  }

  /// "48 reviews"
  String get countLine {
    final n = page.value?.count ?? 0;
    return n == 1 ? LangKeys.crevCountOne.tr : LangKeys.crevCount.trParams({'n': '$n'});
  }

  /// [1★, 2★, 3★, 4★, 5★]
  List<int> get breakdown => page.value?.breakdown ?? const [0, 0, 0, 0, 0];

  String chip(String f) {
    final c = page.value?.counts;
    return switch (f) {
      'needs_reply' => LangKeys.crevNeedsReply.trParams({'n': '${c?.needsReply ?? 0}'}),
      'low' => LangKeys.crevLow.trParams({'n': '${c?.low ?? 0}'}),
      _ => LangKeys.crevAll.trParams({'n': '${c?.all ?? 0}'}),
    };
  }

  String ago(CompanyReviewItemModel r) => ReviewWords.ago(r.createdAt, _clock());

  /// A low review still open: the card is red and its button is "Follow up".
  bool open(CompanyReviewItemModel r) => r.low && r.followup?.status != 'resolved';

  String? quote(CompanyReviewItemModel r) {
    final c = r.comment?.trim();
    return c == null || c.isEmpty ? null : c;
  }

  // ---- taps --------------------------------------------------------------------------------

  Future<void> onCardTap(CompanyReviewItemModel r) async {
    if (r.low) return onFollowUpTap(r);
    await Get.toNamed<void>(RoutesConstants.reviewDetailsScreen, arguments: r.id);
    await load();
  }

  Future<void> onFollowUpTap(CompanyReviewItemModel r) async {
    await Get.toNamed<void>(RoutesConstants.reviewFollowupScreen, arguments: r);
    await load();
  }

  Future<void> onRequestsTap() async {
    await Get.toNamed<void>(RoutesConstants.reviewRequestsScreen);
  }

  Future<void> onSettingsTap() async {
    await Get.toNamed<void>(RoutesConstants.reviewSettingsScreen);
  }

  Future<void> onCreditsTap() async {
    await Get.toNamed<void>(RoutesConstants.creditsScreen);
  }

  Future<void> onFollowupsTap() async {
    await Get.toNamed<void>(RoutesConstants.reviewFollowupsScreen);
  }

  // ---- the reply sheet ---------------------------------------------------------------------

  /// Opens the sheet with the current reply, if any.
  void startReply(CompanyReviewItemModel r) {
    dictation.cancel();
    replyText.text = r.reply?.text ?? '';
  }

  /// "Your reply shows on the customer's report page and to Ramesh."
  String replyNote(CompanyReviewItemModel r) {
    final t = r.technician?.name;
    return t == null || t.isEmpty
        ? LangKeys.crevReplyNotePlain.tr
        : LangKeys.crevReplyNote.trParams({'name': TextUtils.firstName(t)});
  }

  Future<void> onSuggest(CompanyReviewItemModel r) async {
    if (suggesting.value) return;
    suggesting.value = true;
    final result = await reviews.suggestion(r.id);
    suggesting.value = false;
    final text = result.dataOrNull;
    if (text == null) return KnToast.error(result.errorOrNull!.message);
    replyText.text = text;
  }

  /// Sends the reply; true when it went (the sheet closes).
  Future<bool> onSendReply(CompanyReviewItemModel r) async {
    final text = replyText.text.trim();
    if (text.isEmpty || sending.value) return false;
    sending.value = true;
    final result = await reviews.reply(r.id, text);
    sending.value = false;
    if (result.dataOrNull == null) {
      KnToast.error(result.errorOrNull!.message);
      return false;
    }
    KnToast.success(LangKeys.crevReplied.tr);
    await load();
    return true;
  }
}
