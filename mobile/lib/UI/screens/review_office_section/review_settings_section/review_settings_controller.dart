import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/data_access_layer/api_repository/reviews_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/review_words.dart';
import '../../../common_widgets/kn_toast.dart';

/// M46 Review settings and Review follow-ups (owners and managers). Both screens edit the same
/// company settings; Save sends only what changed.
class ReviewSettingsController extends GetxController {
  ReviewSettingsController({required this.reviews, required this.translation});

  final IReviewsApiRepository reviews;
  final TranslationService translation;

  static const channels = ['whatsapp', 'sms', 'email'];

  final Rxn<ReviewSettingsOutModel> saved = Rxn<ReviewSettingsOutModel>();
  final RxBool saving = false.obs;

  final RxBool askOnShare = true.obs;
  final RxBool reminderEnabled = true.obs;
  final RxList<String> reminderChannels = <String>['sms', 'email'].obs;
  final RxBool aiCallEnabled = true.obs;
  final RxBool lowRatingAlert = true.obs;
  final RxBool techsCanRequest = true.obs;
  final RxBool techsSeeReviews = true.obs;
  final RxBool showPublicReviews = false.obs;
  final TextEditingController googleUrl = TextEditingController();
  final RxString googleDraft = ''.obs;

  @override
  void onInit() {
    super.onInit();
    googleUrl.addListener(() => googleDraft.value = googleUrl.text);
    load();
  }

  @override
  void onClose() {
    googleUrl.dispose();
    super.onClose();
  }

  Future<void> load() async {
    final result = await reviews.settings();
    final s = result.dataOrNull;
    if (s == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    _show(s);
  }

  void _show(ReviewSettingsOutModel s) {
    saved.value = s;
    askOnShare.value = s.askOnShare;
    reminderEnabled.value = s.reminderEnabled;
    reminderChannels.assignAll(s.reminderChannels);
    aiCallEnabled.value = s.aiCallEnabled;
    lowRatingAlert.value = s.lowRatingAlert;
    techsCanRequest.value = s.techsCanRequest;
    techsSeeReviews.value = s.techsSeeReviews;
    showPublicReviews.value = s.showPublicReviews;
    googleUrl.text = s.googleReviewUrl ?? '';
  }

  bool get loaded => saved.value != null;

  bool get canEdit => saved.value?.canEdit ?? false;

  // ---- words -------------------------------------------------------------------------------

  /// "If no review after 2 days, by SMS + email"
  String get reminderSub => LangKeys.rsetRemindSub.trParams({
        'n': '${saved.value?.reminderDay ?? 2}',
        'channels': reminderChannels.map(ReviewWords.channel).join(' + '),
      });

  /// "2 stars or less · in the app"
  String get lowSub => LangKeys.rsetLowSub.trParams({'n': '${saved.value?.lowRatingThreshold ?? 2}'});

  /// "Day 2"
  String day(int n) => LangKeys.rfuDay.trParams({'n': '$n'});

  int get reminderDay => saved.value?.reminderDay ?? 2;

  int get aiCallDay => saved.value?.aiCallDay ?? 5;

  /// "One call + voicemail, 10:00 AM – 7:00 PM"
  String get aiSub {
    final parts = (saved.value?.callWindow ?? '10:00-19:00').split('-');
    String at(String hm) {
      final bits = hm.split(':');
      final t = DateTime(2026, 1, 1, int.tryParse(bits.first) ?? 0, int.tryParse(bits.length > 1 ? bits[1] : '0') ?? 0);
      return DateFormat.jm(translation.currentCode).format(t);
    }

    return LangKeys.rfuAiSub.trParams({'from': at(parts.first), 'to': at(parts.length > 1 ? parts[1] : parts.first)});
  }

  String channelLabel(String c) => switch (c) {
        'sms' => LangKeys.shareSms.tr,
        'whatsapp' => LangKeys.shareWhatsapp.tr,
        _ => LangKeys.shareEmail.tr,
      };

  // ---- edits -------------------------------------------------------------------------------

  void onChannelTap(String c) {
    if (!canEdit) return;
    if (reminderChannels.contains(c)) {
      if (reminderChannels.length == 1) return KnToast.info(LangKeys.rfuPickOne.tr);
      reminderChannels.remove(c);
    } else {
      reminderChannels.add(c);
    }
  }

  void toggle(RxBool v, bool to) {
    if (canEdit) v.value = to;
  }

  ReviewSettingsInModel get _changes {
    final s = saved.value!;
    bool? diff(bool now, bool was) => now == was ? null : now;
    final sameChannels = reminderChannels.length == s.reminderChannels.length &&
        reminderChannels.every(s.reminderChannels.contains);
    final url = googleUrl.text.trim();
    return ReviewSettingsInModel(
      askOnShare: diff(askOnShare.value, s.askOnShare),
      reminderEnabled: diff(reminderEnabled.value, s.reminderEnabled),
      reminderChannels: sameChannels ? null : reminderChannels.toList(),
      aiCallEnabled: diff(aiCallEnabled.value, s.aiCallEnabled),
      lowRatingAlert: diff(lowRatingAlert.value, s.lowRatingAlert),
      techsCanRequest: diff(techsCanRequest.value, s.techsCanRequest),
      techsSeeReviews: diff(techsSeeReviews.value, s.techsSeeReviews),
      showPublicReviews: diff(showPublicReviews.value, s.showPublicReviews),
      googleReviewUrl: url == (s.googleReviewUrl ?? '') ? null : url,
    );
  }

  /// Anything to save? (reads every Rx so the Save button follows).
  bool get dirty {
    if (saved.value == null) return false;
    googleDraft.value;
    final c = _changes.toJson()..removeWhere((_, v) => v == null);
    return c.isNotEmpty;
  }

  Future<void> onSave() async {
    if (!dirty || saving.value) return;
    saving.value = true;
    final result = await reviews.saveSettings(_changes);
    saving.value = false;
    final s = result.dataOrNull;
    if (s == null) return KnToast.error(result.errorOrNull!.message);
    _show(s);
    KnToast.success(LangKeys.rsetSaved.tr);
  }
}
