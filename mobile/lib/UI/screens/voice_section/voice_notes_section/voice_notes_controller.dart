import 'dart:async';

import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/voice_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/audio_service.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../common_widgets/kn_toast.dart';
import '../common/voice_texts.dart';

enum NoteTone { done, working, problem, phone }

/// One row on M28: a note on the server or one still on the phone.
class NoteRow {
  const NoteRow({
    required this.id,
    required this.index,
    required this.typed,
    this.server,
    this.pending,
  });

  final String id;
  final int index;
  final bool typed;
  final VoiceNoteItemModel? server;
  final PendingNote? pending;

  bool get onPhone => pending != null;

  double? get seconds => server?.durationS ?? pending?.durationS;

  String? get language => server?.language ?? pending?.languageHint;

  /// A web address or a file on the phone; null for a typed note.
  String? get audio => server?.audioUrl ?? pending?.path;

  String? get excerpt => server?.excerpt ?? pending?.text;

  bool get locked => server?.locked ?? false;
}

/// M28 Voice notes: every note of the job, played here, written out by the server.
class VoiceNotesController extends GetxController {
  VoiceNotesController({
    required this.voice,
    required this.queue,
    required this.player,
    VoiceArguments? args,
    this.pollEvery = const Duration(seconds: 4),
  }) : args = args ?? Get.arguments as VoiceArguments;

  final IVoiceApiRepository voice;
  final PhotoQueueService queue;
  final IVoicePlayer player;
  final VoiceArguments args;

  /// How often to ask again while a note is being written out.
  final Duration pollEvery;

  final RxList<VoiceNoteItemModel> notes = <VoiceNoteItemModel>[].obs;
  final RxBool loaded = false.obs;
  Worker? _sentWorker;
  Timer? _poll;

  @override
  void onInit() {
    super.onInit();
    load();
    _sentWorker = ever(queue.notesSent, (_) => load());
  }

  @override
  void onClose() {
    _sentWorker?.dispose();
    _poll?.cancel();
    player.stop();
    super.onClose();
  }

  Future<void> load() async {
    final result = await voice.notes(args.jobId);
    loaded.value = true;
    final list = result.dataOrNull;
    if (list == null) {
      if (!result.errorOrNull!.isNetwork) KnToast.error(result.errorOrNull!.message);
      return;
    }
    notes.assignAll([...list.data]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt)));
    _poll?.cancel();
    if (notes.any(isWriting)) _poll = Timer(pollEvery, load);
  }

  static bool isWriting(VoiceNoteItemModel n) => n.status == 'uploaded' || n.status == 'transcribing';

  /// Server notes first (oldest first), then the ones still on the phone; numbered in that order.
  List<NoteRow> get rows {
    final pending = queue.notesFor(args.jobId);
    var i = 0;
    return [
      for (final n in notes) NoteRow(id: n.id, index: ++i, typed: n.kind == 'typed', server: n),
      for (final p in pending) NoteRow(id: p.id, index: ++i, typed: p.typed, pending: p),
    ];
  }

  String title(NoteRow r) => (r.typed ? LangKeys.notesTypedItem : LangKeys.notesItem).trParams({'n': '${r.index}'});

  String language(NoteRow r) => VoiceTexts.language(r.language);

  NoteTone tone(NoteRow r) {
    final p = r.pending;
    if (p != null) return p.state == PendingState.failed ? NoteTone.problem : NoteTone.phone;
    return switch (r.server!.status) {
      'transcribed' => NoteTone.done,
      'unclear' || 'failed' => NoteTone.problem,
      _ => NoteTone.working,
    };
  }

  String statusText(NoteRow r) {
    final p = r.pending;
    if (p != null) return p.state == PendingState.failed ? LangKeys.notesNotSent.tr : LangKeys.notesOnPhone.tr;
    return switch (r.server!.status) {
      'transcribed' => LangKeys.notesWritten.tr,
      'unclear' => LangKeys.notesUnclear.tr,
      'failed' => LangKeys.notesFailed.tr,
      _ => LangKeys.notesWriting.tr,
    };
  }

  /// The written text is shown once it is ready (or the typed text).
  String? quote(NoteRow r) {
    final e = r.excerpt;
    if (e == null || e.trim().isEmpty) return null;
    if (r.server != null && !r.typed && r.server!.status != 'transcribed') return null;
    return '“${e.trim()}”';
  }

  bool isPlaying(NoteRow r) => player.current.value == r.id && player.playing.value;

  double progress(NoteRow r) {
    if (player.current.value != r.id) return 0;
    final total = player.duration.value.inMilliseconds;
    return total == 0 ? 0 : player.position.value.inMilliseconds / total;
  }

  Future<void> onPlayTap(NoteRow r) async {
    final source = r.audio;
    if (source != null) await player.toggle(r.id, source);
  }

  Future<void> onOpen(NoteRow r) async {
    if (r.onPhone) {
      if (r.pending!.state == PendingState.failed) return queue.retryNote(r.id);
      return KnToast.info(LangKeys.noteOnPhone.tr);
    }
    await player.stop();
    await Get.toNamed(RoutesConstants.voiceNoteScreen, arguments: args.note(r.id, r.index));
    load();
  }

  /// After the person said yes on the sheet.
  Future<void> delete(NoteRow r) async {
    if (player.current.value == r.id) await player.stop();
    if (r.onPhone) {
      await queue.removeNote(r.id);
    } else {
      final result = await voice.delete(r.id);
      if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
      notes.removeWhere((n) => n.id == r.id);
    }
    KnToast.success(LangKeys.notesDeleted.tr);
  }

  Future<void> onRecordTap() async {
    await player.stop();
    await Get.toNamed(RoutesConstants.voiceRecordScreen, arguments: args.record);
    load();
  }
}
