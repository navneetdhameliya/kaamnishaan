import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/services/audio_service.dart';
import '../../../../infrastructure/services/photo_queue_service.dart';
import '../../../../infrastructure/shared/job_arguments.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_toast.dart';

enum RecordPhase { starting, recording, paused, saving, denied }

/// M27 Voice note: record, pause, stop and save. Saved notes go into the offline queue (D-61);
/// the server writes them out. With the microphone off it explains how to turn it on, or takes a typed note.
class VoiceRecordController extends GetxController with WidgetsBindingObserver {
  VoiceRecordController({
    required this.recorder,
    required this.queue,
    VoiceArguments? args,
    Future<Directory> Function()? temp,
    Future<bool> Function()? openSettings,
    this.autoStart = true,
  })  : args = args ?? Get.arguments as VoiceArguments,
        _temp = temp ?? getTemporaryDirectory,
        _openSettings = openSettings ?? ph.openAppSettings;

  final IVoiceRecorder recorder;
  final PhotoQueueService queue;
  final VoiceArguments args;
  final Future<Directory> Function() _temp;
  final Future<bool> Function() _openSettings;

  /// Tests start recording themselves.
  final bool autoStart;

  /// One note is at most 10 minutes (the server's limit).
  static const maxLength = Duration(minutes: 10);
  static const minLength = Duration(seconds: 1);
  static const _tick = Duration(milliseconds: 200);

  final Rx<RecordPhase> phase = RecordPhase.starting.obs;
  final Rx<Duration> elapsed = Duration.zero.obs;

  /// The loudness of the last moments, 0 to 1, newest last.
  final RxList<double> levels = <double>[].obs;

  /// The language picked on the chips, sent as a hint (null: the server finds it).
  final RxnString language = RxnString();

  final TextEditingController typedController = TextEditingController();
  final RxBool savingTyped = false.obs;

  String? _path;
  Timer? _timer;
  StreamSubscription<double>? _levelsSub;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (autoStart) begin();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicking();
    typedController.dispose();
    if (phase.value == RecordPhase.recording || phase.value == RecordPhase.paused) recorder.stop();
    super.onClose();
  }

  /// Back from the phone settings: try the microphone again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && phase.value == RecordPhase.denied) begin();
  }

  bool get isRecording => phase.value == RecordPhase.recording;

  bool get isPaused => phase.value == RecordPhase.paused;

  String get statusText => switch (phase.value) {
        RecordPhase.paused => LangKeys.voicePaused.trParams({'time': TimeUtils.minSec(elapsed.value)}),
        RecordPhase.starting => LangKeys.voiceStarting.tr,
        _ => LangKeys.voiceRecording.trParams({'time': TimeUtils.minSec(elapsed.value)}),
      };

  /// Asks for the microphone and starts recording.
  Future<void> begin() async {
    phase.value = RecordPhase.starting;
    if (await recorder.askPermission() == MicResult.denied) {
      phase.value = RecordPhase.denied;
      return;
    }
    final dir = await _temp();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (!await recorder.start(path)) {
      phase.value = RecordPhase.denied;
      KnToast.error(LangKeys.voiceMicFailed.tr);
      return;
    }
    _path = path;
    elapsed.value = Duration.zero;
    levels.clear();
    phase.value = RecordPhase.recording;
    _levelsSub = recorder.levels().listen((v) {
      if (!isRecording) return;
      levels.add(v);
      if (levels.length > 80) levels.removeRange(0, levels.length - 80);
    });
    _timer = Timer.periodic(_tick, (_) {
      if (!isRecording) return;
      elapsed.value += _tick;
      if (elapsed.value >= maxLength) {
        KnToast.info(LangKeys.voiceMaxReached.tr);
        onStopSaveTap();
      }
    });
  }

  void _stopTicking() {
    _timer?.cancel();
    _timer = null;
    _levelsSub?.cancel();
    _levelsSub = null;
  }

  Future<void> onPauseTap() async {
    if (isRecording) {
      await recorder.pause();
      phase.value = RecordPhase.paused;
    } else if (isPaused) {
      await recorder.resume();
      phase.value = RecordPhase.recording;
    }
  }

  void onLanguageTap(String code) => language.value = language.value == code ? null : code;

  /// Saves the recording on the phone (it is sent when there is internet) and leaves.
  Future<void> onStopSaveTap() async {
    if (!isRecording && !isPaused) return;
    final kept = await _finish();
    if (kept) _leave();
  }

  /// Stops; keeps the note when it is long enough. false: too short (recording starts again).
  Future<bool> _finish() async {
    phase.value = RecordPhase.saving;
    _stopTicking();
    final path = await recorder.stop() ?? _path;
    final length = elapsed.value;
    if (path == null || length < minLength) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      await begin();
      KnToast.info(LangKeys.voiceTooShort.tr);
      return false;
    }
    await queue.addVoice(
      jobId: args.jobId,
      sourcePath: path,
      durationS: length.inMilliseconds / 1000,
      languageHint: language.value,
    );
    KnToast.success(LangKeys.voiceSaved.tr);
    return true;
  }

  /// Back while recording keeps what was said (proof is never thrown away, D-62).
  Future<void> onBackTap() async {
    if ((isRecording || isPaused) && elapsed.value >= minLength) {
      await _finish();
    } else if (isRecording || isPaused) {
      _stopTicking();
      final path = await recorder.stop();
      phase.value = RecordPhase.starting;
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
    Get.back<bool>(result: true);
  }

  void _leave() {
    if (args.openListAfter) {
      Get.offNamed(RoutesConstants.voiceNotesScreen, arguments: VoiceArguments(jobId: args.jobId, customer: args.customer));
    } else {
      Get.back<bool>(result: true);
    }
  }

  // ---- microphone off ----------------------------------------------------------------------

  Future<void> onOpenSettingsTap() => _openSettings();

  /// "Type notes instead": saves a typed note (D-27).
  Future<bool> onSaveTypedTap() async {
    final text = typedController.text.trim();
    if (text.isEmpty) return false;
    savingTyped.value = true;
    await queue.addTyped(jobId: args.jobId, text: text);
    savingTyped.value = false;
    typedController.clear();
    KnToast.success(LangKeys.voiceTypedSaved.tr);
    return true;
  }

  /// After a typed note from the bottom sheet.
  void afterTyped() => _leave();
}
