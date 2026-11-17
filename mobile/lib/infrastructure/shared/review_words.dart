import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../lang/lang_keys.g.dart';
import '../models/api_models.g.dart';
import 'text_utils.dart';

/// The words of the review card (M15), the ask card (M31) and My reviews (M44), in the app language.
class ReviewWords {
  ReviewWords(this.locale);

  final String locale;

  /// The tag's label: "On time", "Clean work"…
  static String tag(String key) => switch (key) {
        'on_time' => LangKeys.tagOnTime.tr,
        'clean_work' => LangKeys.tagCleanWork.tr,
        'explained_clearly' => LangKeys.tagExplainedClearly.tr,
        'polite' => LangKeys.tagPolite.tr,
        'fixed_first_time' => LangKeys.tagFixedFirstTime.tr,
        'late' => LangKeys.tagLate.tr,
        'messy' => LangKeys.tagMessy.tr,
        'not_fixed' => LangKeys.tagNotFixed.tr,
        'not_explained' => LangKeys.tagNotExplained.tr,
        'rude' => LangKeys.tagRude.tr,
        _ => key,
      };

  static String source(String s) => switch (s) {
        'ai_call' => LangKeys.reviewViaAiCall.tr,
        'reply' => LangKeys.reviewViaReply.tr,
        _ => LangKeys.reviewViaLink.tr,
      };

  static String channel(String c) => switch (c) {
        'sms' => LangKeys.shareSms.tr,
        'whatsapp' => LangKeys.shareWhatsapp.tr,
        _ => LangKeys.shareEmail.tr.toLowerCase(),
      };

  /// "31 Oct"
  String day(DateTime t) => DateFormat('d MMM', locale).format(t.toLocal());

  /// "Mon, 2 Nov · 11:00 AM"
  String dayTime(DateTime t) {
    final l = t.toLocal();
    return '${DateFormat('EEE, d MMM', locale).format(l)} · ${DateFormat.jm(locale).format(l)}';
  }

  /// "Thu, 5 Nov"
  String weekday(DateTime t) => DateFormat('EEE, d MMM', locale).format(t.toLocal());

  /// The chip on the card: "Not asked yet", "Queued", "Waiting for rating", "Rated", "Opted out", "Stopped".
  String chip(JobReviewModel r) => switch (r.status) {
        'not_requested' => LangKeys.reviewNotAsked.tr,
        'queued' => LangKeys.reviewQueued.tr,
        'rated' => LangKeys.reviewRated.tr,
        'opted_out' => LangKeys.reviewOptedOut.tr,
        'stopped' || 'paused_no_credits' => LangKeys.reviewStopped.tr,
        _ => LangKeys.reviewWaiting.tr,
      };

  String contact(JobReviewModel r) {
    final n = r.contactName?.trim();
    return n == null || n.isEmpty ? LangKeys.reviewTheCustomer.tr : n;
  }

  /// Under "Not asked yet": what happens, or why it can't be asked.
  String notAskedBody(JobReviewModel r) => switch (r.blockedReason) {
        'no_contact' => LangKeys.reviewNoContact.tr,
        'not_allowed' => LangKeys.reviewNotAllowed.tr,
        _ => (r.aiCallEnabled ?? true ? LangKeys.reviewNotAskedBody : LangKeys.reviewNotAskedBodyNoCall)
            .trParams({'name': contact(r)}),
      };

  /// "31 Oct · SMS + email"
  String sentLine(JobReviewModel r) {
    final at = r.sentAt;
    final how = (r.channels ?? const <String>[]).map(channel).join(' + ');
    return [if (at != null) day(at), if (how.isNotEmpty) how].join(' · ');
  }

  String? reminderLine(JobReviewModel r) {
    final at = r.reminderAt;
    return at == null ? null : dayTime(at);
  }

  String? aiCallLine(JobReviewModel r) {
    final at = r.aiCallAt;
    return at == null ? null : LangKeys.reviewIfNoRating.trParams({'date': weekday(at)});
  }

  /// "Requested by you · no need to ask again."
  String requestedBy(JobReviewModel r) {
    if (r.requestedByMe ?? false) return LangKeys.reviewByYou.tr;
    final who = r.requestedBy?.name;
    return who == null ? LangKeys.reviewByYou.tr : LangKeys.reviewByName.trParams({'name': TextUtils.firstName(who)});
  }

  /// "4 · via AI call · 5 Nov"
  String ratedLine(ReviewBriefModel b) => LangKeys.reviewRatedLine.trParams({
        'n': '${b.technicianRating ?? b.rating}',
        'source': source(b.source),
        'date': day(b.createdAt),
      });

  String optedOutLine(JobReviewModel r) {
    final at = r.optedOutAt;
    return at == null ? '' : LangKeys.reviewOptedOutLine.trParams({'date': day(at)});
  }

  /// "2 h ago", "3 days ago"
  static String ago(DateTime t, DateTime now) {
    final m = now.difference(t.toLocal()).inMinutes;
    if (m < 1) return LangKeys.queueJustNow.tr;
    if (m < 60) return LangKeys.queueMinAgo.trParams({'n': '$m'});
    if (m < 60 * 24) return LangKeys.queueHAgo.trParams({'n': '${m ~/ 60}'});
    return LangKeys.queueDaysAgo.trParams({'n': '${m ~/ (60 * 24)}'});
  }
}
