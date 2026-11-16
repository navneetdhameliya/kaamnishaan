import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/lang/translation_service.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

enum WaitKind { photo, voice, typed, answers }

/// One line on "Waiting to send".
class WaitItem {
  const WaitItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.state,
    this.path,
  });

  final String id;
  final WaitKind kind;
  final String title;
  final String subtitle;
  final PendingState state;

  /// The photo on the phone, for its thumbnail.
  final String? path;
}

/// M43 Waiting to send: everything saved on this phone that the server does not have yet, and
/// "Send all now". When it is all sent: "Everything is sent".
class WaitingToSendController extends GetxController {
  WaitingToSendController({required this.queue, required this.translation});

  final PhotoQueueService queue;
  final TranslationService translation;

  /// How many were waiting when the screen opened, for the progress bar.
  int _start = 0;
  final RxInt sentPhotos = 0.obs;
  final RxInt sentNotes = 0.obs;
  final Rxn<DateTime> lastSent = Rxn<DateTime>();
  final RxBool sending = false.obs;
  final List<Worker> _workers = [];

  @override
  void onInit() {
    super.onInit();
    _start = queue.total;
    _workers
      ..add(ever(queue.sent, (_) => _count(sentPhotos)))
      ..add(ever(queue.notesSent, (_) => _count(sentNotes)));
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  void _count(RxInt counter) {
    counter.value++;
    lastSent.value = DateTime.now();
  }

  int get total => queue.total;

  int get failed => queue.failedCount;

  bool get allSent => total == 0;

  int get sentCount => sentPhotos.value + sentNotes.value;

  double get progress => _start == 0 ? 1 : ((_start - total) / _start).clamp(0.0, 1.0);

  String get summary => failed > 0
      ? LangKeys.pendingSummaryFailed.trParams({'n': '$total', 'failed': '$failed'})
      : LangKeys.pendingSummary.trParams({'n': '$total'});

  String _stage(String stage) => switch (stage) {
        'before' => LangKeys.stageBefore.tr,
        'during' => LangKeys.stageDuring.tr,
        _ => LangKeys.stageAfter.tr,
      };

  String _line(String? customer, String detail) =>
      [if (customer != null && customer.isNotEmpty) customer, detail].join(' · ');

  /// Newest first: photos and notes one by one; checklist answers as one line.
  List<WaitItem> get items {
    final code = translation.currentCode;
    final rows = <(DateTime, WaitItem)>[
      for (final p in queue.items)
        (
          p.takenAt,
          WaitItem(
            id: p.id,
            kind: WaitKind.photo,
            title: LangKeys.pendingPhoto.trParams({'stage': _stage(p.stage)}),
            subtitle: _line(p.customer, TimeUtils.clock(p.takenAt, code)),
            state: p.state,
            path: p.path,
          ),
        ),
      for (final n in queue.notes)
        (
          n.recordedAt,
          WaitItem(
            id: n.id,
            kind: n.typed ? WaitKind.typed : WaitKind.voice,
            title: n.typed ? LangKeys.pendingTyped.tr : LangKeys.pendingVoice.tr,
            subtitle: _line(
              n.customer,
              n.durationS == null
                  ? TimeUtils.clock(n.recordedAt, code)
                  : TimeUtils.minSec(Duration(milliseconds: (n.durationS! * 1000).round())),
            ),
            state: n.state,
          ),
        ),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final answers = queue.answers;
    return [
      ...rows.map((r) => r.$2),
      if (answers.isNotEmpty)
        WaitItem(
          id: 'answers',
          kind: WaitKind.answers,
          title: LangKeys.pendingAnswers.trParams({'n': '${answers.length}'}),
          subtitle: '',
          state: answers.any((a) => a.state == PendingState.failed) ? PendingState.failed : PendingState.waiting,
        ),
    ];
  }

  String get sentDetail => LangKeys.pendingSentDetail.trParams({'photos': '${sentPhotos.value}', 'notes': '${sentNotes.value}'});

  String get sentAt => LangKeys.pendingSentAt.trParams({
        'time': TimeUtils.clock(lastSent.value ?? DateTime.now(), translation.currentCode),
      });

  Future<void> onTryAgainTap(WaitItem item) => switch (item.kind) {
        WaitKind.photo => queue.retry(item.id),
        WaitKind.voice || WaitKind.typed => queue.retryNote(item.id),
        WaitKind.answers => queue.retryAll(),
      };

  /// Sends everything now, "Not sent" ones too. Without internet they keep waiting.
  Future<void> onSendAllTap() async {
    final before = total;
    sending.value = true;
    await queue.retryAll();
    sending.value = false;
    if (total > 0 && total == before) KnToast.info(LangKeys.pendingNoInternet.tr);
  }

  void onBackTodayTap() => Get.offAllNamed<void>(RoutesConstants.homeScreen);
}
