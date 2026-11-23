import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/notifications_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

enum MessageTone { job, review, problem, done, news }

/// M42 Messages: new jobs and what happened to reports, newest first, grouped by day. The sentence is
/// written here, in the app's language, from what the server sends (`kind` and the names in `params`).
/// Opening the list marks everything read; this visit still shows which ones were new.
class MessagesController extends GetxController {
  MessagesController({required this.repository, required this.translation, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final INotificationsApiRepository repository;
  final TranslationService translation;
  final DateTime Function() _clock;

  final RxList<NotificationOutModel> items = <NotificationOutModel>[].obs;
  final RxBool loaded = false.obs;

  /// Unread when the list opened (their red dots stay for this visit).
  final RxSet<String> fresh = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    final result = await repository.list(limit: 50);
    loaded.value = true;
    final list = result.dataOrNull;
    if (list == null) {
      final e = result.errorOrNull!;
      if (!e.isNetwork) KnToast.error(e.message);
      return;
    }
    items.assignAll(list.data);
    fresh.addAll(list.data.where((n) => !n.read).map((n) => n.id));
    if (list.data.any((n) => !n.read)) await repository.read();
  }

  String get subtitle =>
      fresh.isEmpty ? LangKeys.messagesNoneNew.tr : LangKeys.messagesNew.trParams({'n': '${fresh.length}'});

  String get _code => translation.currentCode;

  DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  /// [("Today", [...]), ("Yesterday", [...]), ("Thu 29 Oct", [...])]
  List<(String, List<NotificationOutModel>)> get groups {
    final today = _day(_clock());
    final out = <(String, List<NotificationOutModel>)>[];
    for (final n in items) {
      final d = _day(n.createdAt.toLocal());
      final title = d == today
          ? LangKeys.messagesToday.tr
          : d == today.subtract(const Duration(days: 1))
              ? LangKeys.messagesYesterday.tr
              : DateFormat('EEE d MMM', _code).format(d);
      if (out.isEmpty || out.last.$1 != title) out.add((title, []));
      out.last.$2.add(n);
    }
    return out;
  }

  String _p(NotificationOutModel n, String key) => '${n.params[key] ?? ''}';

  String _who(NotificationOutModel n) => n.actor?.name.split(' ').first ?? LangKeys.msgYourManager.tr;

  bool _isToday(DateTime t) => _day(t.toLocal()) == _day(_clock());

  String title(NotificationOutModel n) => switch (n.kind) {
        'job_assigned' => _scheduled(n) != null && _isToday(_scheduled(n)!)
            ? LangKeys.msgJobTitleToday.tr
            : LangKeys.msgJobTitle.tr,
        'report_submitted' => LangKeys.msgSubmittedTitle.tr,
        'changes_requested' => LangKeys.msgChangesTitle.tr,
        'review_received' => LangKeys.msgReviewTitle.tr,
        'low_rating' => LangKeys.msgLowTitle.tr,
        'support_reply' => LangKeys.msgSupportTitle.tr,
        'tech_question' => LangKeys.msgQuestionTitle.tr,
        'announcement' => _inLanguage(n, 'title'),
        _ => LangKeys.msgApprovedTitle.tr,
      };

  /// A29 announcements carry their text in each language ("title_hi"); English when there is none.
  String _inLanguage(NotificationOutModel n, String part) {
    final mine = _p(n, '${part}_$_code');
    return mine.isNotEmpty ? mine : _p(n, '${part}_en');
  }

  DateTime? _scheduled(NotificationOutModel n) => DateTime.tryParse(_p(n, 'scheduled_at'));

  String body(NotificationOutModel n) {
    final customer = _p(n, 'customer');
    switch (n.kind) {
      case 'job_assigned':
        final at = _scheduled(n);
        final when = at == null
            ? null
            : _isToday(at)
                ? TimeUtils.clock(at, _code)
                : '${DateFormat('EEE d MMM', _code).format(at.toLocal())} ${TimeUtils.clock(at, _code)}';
        return [customer, ?when, _p(n, 'job')].where((s) => s.isNotEmpty).join(' · ');
      case 'report_submitted':
        final tech = _p(n, 'technician');
        return LangKeys.msgSubmittedBody.trParams({
          'technician': tech.isEmpty ? LangKeys.msgTechnician.tr : tech.split(' ').first,
          'customer': customer,
        });
      case 'changes_requested':
        final note = _p(n, 'note');
        return note.isEmpty
            ? LangKeys.msgChangesBodyPlain.trParams({'who': _who(n), 'customer': customer})
            : LangKeys.msgChangesBody.trParams({'who': _who(n), 'customer': customer, 'note': note});
      case 'tech_question':
        final tech = _p(n, 'technician');
        final note = _p(n, 'note');
        final words = {
          'technician': tech.isEmpty ? LangKeys.msgTechnician.tr : tech.split(' ').first,
          'customer': customer,
          'question': _p(n, 'question'),
          'note': note,
        };
        return note.isEmpty
            ? LangKeys.msgQuestionBody.trParams(words)
            : LangKeys.msgQuestionBodyNote.trParams(words);
      case 'report_shared':
        return LangKeys.msgSharedBody.trParams({'customer': customer});
      case 'review_received':
        return LangKeys.msgReviewBody.trParams({'customer': customer, 'n': _p(n, 'rating')});
      case 'low_rating':
        return LangKeys.msgLowBody.trParams({'customer': customer, 'n': _p(n, 'rating')});
      case 'support_reply':
        return LangKeys.msgSupportBody.trParams({'subject': _p(n, 'subject')});
      case 'announcement':
        return _inLanguage(n, 'body');
      default:
        return LangKeys.msgApprovedBody.trParams({'customer': customer});
    }
  }

  /// "Just now", "10 min", "1 h", then the clock time.
  String when(NotificationOutModel n) {
    final t = n.createdAt.toLocal();
    final ago = _clock().difference(t);
    if (ago.inMinutes < 1) return LangKeys.messagesJustNow.tr;
    if (ago.inMinutes < 60) return LangKeys.messagesMinutes.trParams({'n': '${ago.inMinutes}'});
    if (ago.inHours < 3) return LangKeys.messagesHours.trParams({'n': '${ago.inHours}'});
    return TimeUtils.clock(t, _code);
  }

  MessageTone tone(NotificationOutModel n) => switch (n.kind) {
        'job_assigned' => MessageTone.job,
        'report_submitted' || 'tech_question' => MessageTone.review,
        'changes_requested' || 'low_rating' => MessageTone.problem,
        'support_reply' || 'announcement' => MessageTone.news,
        _ => MessageTone.done,
      };

  /// Opens what the message is about: the job, its proof (to fix it) or the report.
  Future<void> onOpen(NotificationOutModel n) async {
    if (n.kind == 'support_reply') {
      final ticket = _p(n, 'ticket_id');
      if (ticket.isNotEmpty) await Get.toNamed(RoutesConstants.helpTicketScreen, arguments: ticket);
      return;
    }
    final job = n.jobId;
    if (job == null) return;
    final customer = _p(n, 'customer');
    switch (n.kind) {
      case 'job_assigned' || 'tech_question':
        await Get.toNamed(RoutesConstants.jobDetailsScreen, arguments: JobArguments(id: job, customer: customer));
      case 'changes_requested':
        await Get.toNamed(RoutesConstants.captureHubScreen, arguments: JobArguments(id: job, customer: customer));
      case 'review_received':
        await Get.toNamed(RoutesConstants.myReviewsScreen);
      case 'low_rating':
        await Get.toNamed(RoutesConstants.companyReviewsScreen, arguments: 'low');
      default:
        if (n.reportId == null) return;
        await Get.toNamed(
          RoutesConstants.reportDraftScreen,
          arguments: ReportArguments(jobId: job, customer: customer, reportId: n.reportId, coverUrl: n.coverUrl),
        );
    }
  }
}
