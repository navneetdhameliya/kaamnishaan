import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// The only way to log. Silent in release builds.
abstract final class AppLogger {
  static void info(String message, {String tag = 'kn'}) {
    if (kDebugMode) developer.log(message, name: tag);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace, String tag = 'kn'}) {
    if (!kDebugMode) return;
    developer.log(message, name: tag, error: error, stackTrace: stackTrace, level: 1000);
    // also in Android Studio's / Xcode's Run window (developer.log only shows in DevTools)
    debugPrint('[$tag] $message${error == null ? '' : ': $error'}');
    if (stackTrace != null) debugPrint('$stackTrace');
  }
}
