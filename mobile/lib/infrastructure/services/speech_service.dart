import 'package:flutter_tts/flutter_tts.dart';

import '../shared/app_logger.dart';

/// Read-aloud for low-literacy users (speaker buttons, "Hear it" on errors).
abstract class ISpeechService {
  Future<void> speak(String text, {required String languageCode});
  Future<void> stop();
}

class SpeechService implements ISpeechService {
  SpeechService([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  static const _voices = {'en': 'en-IN', 'hi': 'hi-IN', 'gu': 'gu-IN', 'es': 'es-ES', 'fr': 'fr-FR'};

  @override
  Future<void> speak(String text, {required String languageCode}) async {
    try {
      await _tts.stop();
      await _tts.setLanguage(_voices[languageCode] ?? 'en-IN');
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } catch (e) {
      AppLogger.error('Read aloud failed', error: e);
    }
  }

  @override
  Future<void> stop() => _tts.stop();
}
