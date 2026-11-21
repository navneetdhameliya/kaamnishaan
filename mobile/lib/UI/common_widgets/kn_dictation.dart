import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';

import '../../infrastructure/data_access_layer/api_repository/files_api_repository.dart';
import '../../infrastructure/data_access_layer/api_repository/voice_api_repository.dart';
import '../../infrastructure/lang/lang_keys.g.dart';
import '../../infrastructure/services/audio_service.dart';
import '../commons/text_widgets/base/custom_base_text_widget.dart';
import '../theme/kn_app_theme.dart';
import '../theme/kn_tokens.g.dart';
import 'custom_inkwell.dart';
import 'kn_toast.dart';

/// The microphone in a text box: off, listening, or turning the words into text.
enum DictationPhase { idle, listening, working }

/// Speak instead of typing (D-134, D-135). One per screen: tap a box's microphone, speak, tap again; the
/// recording is turned into words on the server (`POST /dictation`) and added to that box. Nothing is kept.
class Dictation {
  Dictation({
    required this.recorder,
    required this.files,
    required this.voice,
    Future<Directory> Function()? temp,
    this.max = const Duration(seconds: 60),
  }) : _temp = temp ?? getTemporaryDirectory;

  /// The phone's own services, for a screen's binding.
  factory Dictation.find() => Dictation(recorder: Get.find(), files: Get.find(), voice: Get.find());

  final IVoiceRecorder recorder;
  final IFilesApiRepository files;
  final IVoiceApiRepository voice;
  final Future<Directory> Function() _temp;

  /// Listening stops on its own after this.
  final Duration max;

  final Rx<DictationPhase> phase = DictationPhase.idle.obs;

  /// The box the words go into while listening or working.
  final Rxn<TextEditingController> target = Rxn<TextEditingController>();

  Timer? _limit;
  int _run = 0; // a cancel during "working" makes the late answer go nowhere
  String? _path;
  String? _language;
  ValueChanged<String>? _onText;

  /// Whether [box]'s microphone is the one in use (each box shows its own state).
  DictationPhase phaseOf(TextEditingController box) => target.value == box ? phase.value : DictationPhase.idle;

  /// Tap on [box]'s microphone: start listening, or stop and write the words in. [language] helps the
  /// server hear the right language; [onText] runs after the words are added.
  Future<void> toggle(TextEditingController box, {String? language, ValueChanged<String>? onText}) async {
    switch (phase.value) {
      case DictationPhase.idle:
        await _start(box, language, onText);
      case DictationPhase.listening:
        if (target.value == box) {
          await _finish();
        } else {
          cancel();
          await _start(box, language, onText);
        }
      case DictationPhase.working:
        return;
    }
  }

  Future<void> _start(TextEditingController box, String? language, ValueChanged<String>? onText) async {
    if (await recorder.askPermission() == MicResult.denied) return KnToast.info(LangKeys.dictateOff.tr);
    final path = '${(await _temp()).path}/dictation_${DateTime.now().millisecondsSinceEpoch}.m4a';
    if (!await recorder.start(path)) return KnToast.error(LangKeys.voiceMicFailed.tr);
    _run++;
    _path = path;
    _language = language;
    _onText = onText;
    target.value = box;
    phase.value = DictationPhase.listening;
    _limit = Timer(max, _finish);
  }

  Future<void> _finish() async {
    if (phase.value != DictationPhase.listening) return;
    _limit?.cancel();
    phase.value = DictationPhase.working;
    final run = _run;
    final box = target.value;
    final path = await recorder.stop() ?? _path;
    _path = null;
    final file = path == null ? null : File(path);
    if (box == null || file == null || !file.existsSync()) return _reset();
    final bytes = await file.readAsBytes();
    file.delete().ignore();
    final upload = await files.upload(kind: UploadKind.audio, bytes: bytes, contentType: 'audio/mp4');
    final uploadId = upload.dataOrNull;
    final result = uploadId == null ? null : await voice.dictate(uploadId, languageHint: _language);
    if (run != _run) return; // cancelled while working: the box may be gone
    final onText = _onText;
    _reset();
    final words = result?.dataOrNull?.text;
    if (words == null) {
      return KnToast.error(switch ((result?.errorOrNull ?? upload.errorOrNull)?.code) {
        'unclear' => LangKeys.dictateUnclear.tr,
        'ai_unavailable' => LangKeys.dictateNoAi.tr,
        _ => LangKeys.dictateFailed.tr,
      });
    }
    final before = box.text.trimRight();
    box.text = before.isEmpty ? words : '$before $words';
    box.selection = TextSelection.collapsed(offset: box.text.length);
    onText?.call(box.text);
  }

  void _reset() {
    _limit?.cancel();
    _path = null;
    _onText = null;
    target.value = null;
    phase.value = DictationPhase.idle;
  }

  /// Stops listening without using what was said (the box closed or changed).
  void cancel() {
    _run++;
    if (phase.value == DictationPhase.listening) {
      unawaited(recorder.stop().then((p) {
        if (p != null) File(p).delete().ignore();
      }));
    }
    _reset();
  }
}


/// The microphone at the end of a text box: tap to speak, tap the square to stop; a spinner while the
/// words are written. [filled] gives it a round background (for boxes without a border).
class KnMicButton extends StatelessWidget {
  const KnMicButton({
    super.key,
    required this.dictation,
    required this.box,
    this.language,
    this.onText,
    this.size = 44,
    this.filled = false,
    this.enabled = true,
  });

  final Dictation dictation;
  final TextEditingController box;
  final String? language;
  final ValueChanged<String>? onText;
  final double size;
  final bool filled;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Obx(() => _build(context));

  Widget _build(BuildContext context) {
    final kn = context.kn;
    final phase = dictation.phaseOf(box);
    final listening = phase == DictationPhase.listening;
    return CustomInkWell(
      onTap: !enabled || phase == DictationPhase.working
          ? null
          : () => dictation.toggle(box, language: language ?? Get.locale?.languageCode, onText: onText),
      borderRadius: BorderRadius.circular(KnSize.radiusFull),
      semanticLabel: listening ? LangKeys.dictateStop.tr : LangKeys.dictateSpeak.tr,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: listening ? kn.statusDangerBg : (filled ? kn.actionSecondary : Colors.transparent),
          shape: BoxShape.circle,
        ),
        child: switch (phase) {
          DictationPhase.working => SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: kn.textSecondary),
            ),
          DictationPhase.listening => Icon(LucideIcons.square, size: 18, color: kn.statusDanger),
          DictationPhase.idle => Icon(LucideIcons.mic, size: 20, color: enabled ? kn.textPrimary : kn.textSecondary),
        },
      ),
    );
  }
}

/// "Listening… tap the square to stop" / "Writing it down…" under the box whose microphone is in use.
class KnDictationNote extends StatelessWidget {
  const KnDictationNote({super.key, required this.dictation, required this.box});

  final Dictation dictation;
  final TextEditingController box;

  @override
  Widget build(BuildContext context) => Obx(() => _build(context));

  Widget _build(BuildContext context) {
    final kn = context.kn;
    final phase = dictation.phaseOf(box);
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: phase == DictationPhase.idle
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: KnSize.space8),
              child: CustomBaseTextWidget(
                phase == DictationPhase.listening ? LangKeys.dictateListening.tr : LangKeys.dictateWorking.tr,
                style: context.knText.labelSm,
                color: phase == DictationPhase.listening ? kn.statusDanger : kn.textSecondary,
              ),
            ),
    );
  }
}
