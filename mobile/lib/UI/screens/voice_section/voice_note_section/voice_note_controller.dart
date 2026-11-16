import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/voice_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/services/audio_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';
import '../common/voice_texts.dart';

/// M29 Transcript: the recording, the language, and the written text, which the technician can fix by
/// typing or by speaking a new note. The recording itself is always kept.
class VoiceNoteController extends GetxController {
  VoiceNoteController({
    required this.voice,
    required this.player,
    VoiceArguments? args,
    this.pollEvery = const Duration(seconds: 4),
  }) : args = args ?? Get.arguments as VoiceArguments;

  final IVoiceApiRepository voice;
  final IVoicePlayer player;
  final VoiceArguments args;
  final Duration pollEvery;

  final Rxn<VoiceNoteOutModel> note = Rxn<VoiceNoteOutModel>();
  final RxBool editing = false.obs;
  final RxBool saving = false.obs;
  final TextEditingController textController = TextEditingController();
  Timer? _poll;

  String get noteId => args.noteId!;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    _poll?.cancel();
    textController.dispose();
    player.stop();
    super.onClose();
  }

  Future<void> load() async {
    final result = await voice.note(noteId);
    final n = result.dataOrNull;
    if (n == null) {
      if (!result.errorOrNull!.isNetwork) KnToast.error(result.errorOrNull!.message);
      return;
    }
    note.value = n;
    _poll?.cancel();
    if (writing) _poll = Timer(pollEvery, load);
  }

  bool get typed => note.value?.kind == 'typed';

  bool get writing => const {'uploaded', 'transcribing'}.contains(note.value?.status);

  bool get unclear => note.value?.status == 'unclear';

  bool get failed => note.value?.status == 'failed';

  bool get canEdit => note.value?.canEdit ?? false;

  String get title => (typed ? LangKeys.notesTypedItem : LangKeys.notesItem).trParams({'n': '${args.index}'});

  /// "Green Valley Clinic · 0:42"
  String get subtitle {
    final s = note.value?.durationS;
    if (s == null || typed) return args.customer;
    return LangKeys.noteSubtitle.trParams({
      'customer': args.customer,
      'time': TimeUtils.minSec(Duration(milliseconds: (s * 1000).round())),
    });
  }

  /// "Gujarati, written in English", "Gujarati · not clear", or just "Gujarati".
  String get languageLine {
    final n = note.value;
    final spoken = VoiceTexts.language(n?.language);
    if (n == null || spoken.isEmpty) return '';
    if (unclear) return LangKeys.noteNotClear.trParams({'language': spoken});
    final target = n.translatedTo;
    if (target != null && target.isNotEmpty && target.split('-').first != n.language?.split('-').first) {
      return LangKeys.noteWrittenIn.trParams({'language': spoken, 'target': VoiceTexts.language(target)});
    }
    return spoken;
  }

  /// What goes into the report: the person's own edit, else the translation, else the words as said.
  String get reportText => note.value?.textForReport?.trim() ?? '';

  // ---- player ------------------------------------------------------------------------------

  bool get playing => player.current.value == noteId && player.playing.value;

  Duration get length {
    final mine = player.current.value == noteId ? player.duration.value : Duration.zero;
    if (mine > Duration.zero) return mine;
    final s = note.value?.durationS ?? 0;
    return Duration(milliseconds: (s * 1000).round());
  }

  Duration get position => player.current.value == noteId ? player.position.value : Duration.zero;

  double get progress => length.inMilliseconds == 0 ? 0 : position.inMilliseconds / length.inMilliseconds;

  Future<void> onPlayTap() async {
    final url = note.value?.audioUrl;
    if (url != null) await player.toggle(noteId, url);
  }

  // ---- changing the text -------------------------------------------------------------------

  void onEditTap() {
    if (!canEdit) return KnToast.info(LangKeys.noteLocked.tr);
    textController.text = reportText;
    editing.value = true;
  }

  /// "Save": keeps a typed change, then goes back to the list.
  Future<void> onSaveTap() async {
    if (editing.value) {
      final text = textController.text.trim();
      if (text.isNotEmpty && text != reportText) {
        saving.value = true;
        final result = await voice.edit(noteId, text);
        saving.value = false;
        final n = result.dataOrNull;
        if (n == null) return KnToast.error(result.errorOrNull!.message);
        note.value = n;
        KnToast.success(LangKeys.noteSaved.tr);
      }
      editing.value = false;
    }
    Get.back<bool>(result: true);
  }

  /// "Speak to change" / "Speak again": records a new note; this recording stays (D-62).
  Future<void> onSpeakTap() async {
    if (!canEdit) return KnToast.info(LangKeys.noteLocked.tr);
    await player.stop();
    await Get.toNamed(RoutesConstants.voiceRecordScreen, arguments: args.record);
    Get.back<bool>(result: true);
  }

  /// "Type instead" when the words were not clear.
  void onTypeInsteadTap() => onEditTap();

  /// "Try again" when writing it out failed.
  Future<void> onRetryTap() async {
    saving.value = true;
    final result = await voice.retranscribe(noteId);
    saving.value = false;
    final n = result.dataOrNull;
    if (n == null) return KnToast.error(result.errorOrNull!.message);
    note.value = n;
    _poll?.cancel();
    if (writing) _poll = Timer(pollEvery, load);
  }
}
