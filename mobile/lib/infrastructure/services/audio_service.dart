import 'dart:async';

import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../shared/app_logger.dart';

enum MicResult { ready, denied }

/// The phone microphone for voice notes (M27). Screens use this, never the plugin, so tests can fake it.
abstract class IVoiceRecorder {
  /// Asks for the microphone the first time; [MicResult.denied] when it is off.
  Future<MicResult> askPermission();

  /// Starts recording into [path] (AAC in an .m4a file). false when the microphone could not start.
  Future<bool> start(String path);

  Future<void> pause();
  Future<void> resume();

  /// Stops and returns the file path, or null when nothing was recorded.
  Future<String?> stop();

  /// How loud it is now, 0 (quiet) to 1 (loud), about 10 times a second while recording.
  Stream<double> levels();

  Future<void> dispose();
}

class VoiceRecorder implements IVoiceRecorder {
  AudioRecorder? _recorder;

  AudioRecorder get _rec => _recorder ??= AudioRecorder();

  @override
  Future<MicResult> askPermission() async {
    // the recorder's own request works on iPhone without extra permission_handler build settings
    try {
      return await _rec.hasPermission() ? MicResult.ready : MicResult.denied;
    } catch (e) {
      AppLogger.error('Microphone permission check failed', error: e);
      return MicResult.denied;
    }
  }

  @override
  Future<bool> start(String path) async {
    try {
      await _rec.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
        path: path,
      );
      return true;
    } catch (e) {
      AppLogger.error('Recording did not start', error: e);
      return false;
    }
  }

  @override
  Future<void> pause() => _rec.pause();

  @override
  Future<void> resume() => _rec.resume();

  @override
  Future<String?> stop() async {
    try {
      return await _rec.stop();
    } catch (e) {
      AppLogger.error('Recording did not stop cleanly', error: e);
      return null;
    }
  }

  @override
  Stream<double> levels() => _rec
      .onAmplitudeChanged(const Duration(milliseconds: 100))
      // dBFS: about -60 (quiet room) to 0 (very loud)
      .map((a) => ((a.current + 60) / 60).clamp(0.0, 1.0));

  @override
  Future<void> dispose() async {
    await _recorder?.dispose();
    _recorder = null;
  }
}

/// Plays one voice note at a time (M28, M29): from the server, or from the phone while it is still waiting.
abstract class IVoicePlayer {
  /// The note being played (or paused part way), null when stopped.
  RxnString get current;
  RxBool get playing;
  Rx<Duration> get position;
  Rx<Duration> get duration;

  /// Plays [source] (a web address or a file on the phone), or pauses it when it is already playing.
  Future<void> toggle(String id, String source);

  Future<void> seek(Duration to);
  Future<void> stop();
}

class VoicePlayer extends GetxService implements IVoicePlayer {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  @override
  final RxnString current = RxnString();
  @override
  final RxBool playing = false.obs;
  @override
  final Rx<Duration> position = Duration.zero.obs;
  @override
  final Rx<Duration> duration = Duration.zero.obs;

  @override
  void onInit() {
    super.onInit();
    _subs
      ..add(_player.positionStream.listen((p) => position.value = p))
      ..add(_player.durationStream.listen((d) => duration.value = d ?? Duration.zero))
      ..add(
        _player.playerStateStream.listen((s) {
          playing.value = s.playing && s.processingState != ProcessingState.completed;
          if (s.processingState == ProcessingState.completed) {
            _player.pause();
            _player.seek(Duration.zero);
          }
        }),
      );
  }

  @override
  Future<void> toggle(String id, String source) async {
    try {
      if (current.value == id) {
        playing.value ? await _player.pause() : unawaited(_player.play());
        return;
      }
      await _player.stop();
      current.value = id;
      position.value = Duration.zero;
      source.startsWith('http') ? await _player.setUrl(source) : await _player.setFilePath(source);
      unawaited(_player.play());
    } catch (e) {
      AppLogger.error('Playing the voice note failed', error: e);
      current.value = null;
    }
  }

  @override
  Future<void> seek(Duration to) => _player.seek(to);

  @override
  Future<void> stop() async {
    await _player.stop();
    current.value = null;
    position.value = Duration.zero;
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.onClose();
  }
}
