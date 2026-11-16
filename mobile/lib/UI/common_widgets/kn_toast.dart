import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

/// Short messages at the top of the screen. Controllers call these; repositories never do.
abstract final class KnToast {
  static void error(String message) => _show(message, ToastificationType.error);
  static void success(String message) => _show(message, ToastificationType.success);
  static void info(String message) => _show(message, ToastificationType.info);

  static void _show(String message, ToastificationType type) {
    toastification.show(
      type: type,
      style: ToastificationStyle.flatColored,
      title: Text(message, maxLines: 3),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 4),
      showProgressBar: false,
    );
  }
}
