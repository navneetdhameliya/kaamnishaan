import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/shared/app_logger.dart';
import '../../../../infrastructure/shared/navigation_utils.dart';
import '../../../common_widgets/kn_toast.dart';

/// M08 Check your email: the reset link was sent. "Send again" unlocks after a minute.
class CheckEmailController extends GetxController {
  CheckEmailController({required this.repository, String? email, Future<bool> Function(Uri uri)? openUrl})
      : email = email ?? (Get.arguments is String ? Get.arguments as String : ''),
        _openUrl = openUrl ?? ((uri) => launchUrl(uri));

  final IAuthApiRepository repository;
  final Future<bool> Function(Uri uri) _openUrl;

  static const resendSeconds = 60;

  /// Where the link went (passed from M08 Forgot password).
  final String email;
  final RxInt secondsLeft = 0.obs;
  final RxBool resending = false.obs;
  Timer? _timer;

  @override
  void onInit() {
    super.onInit();
    _startTimer();
  }

  String get waitText {
    final s = secondsLeft.value;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _startTimer() {
    _timer?.cancel();
    secondsLeft.value = resendSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft.value <= 1) {
        secondsLeft.value = 0;
        t.cancel();
      } else {
        secondsLeft.value--;
      }
    });
  }

  Future<void> callResendAPI() async {
    if (secondsLeft.value > 0 || resending.value || email.isEmpty) return;
    resending.value = true;
    final result = await repository.forgotPassword(email);
    resending.value = false;
    if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
    KnToast.success(LangKeys.forgotSentAgain.tr);
    _startTimer();
  }

  /// iPhone: the Mail app's inbox. Android: the email app (its compose screen; the inbox is one tap away).
  Future<void> onOpenMailTap() async {
    final ios = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
    final uri = ios ? Uri.parse('message://') : Uri(scheme: 'mailto');
    var opened = false;
    try {
      opened = await _openUrl(uri);
    } catch (e) {
      AppLogger.error('Opening the email app failed', error: e);
    }
    if (!opened) KnToast.info(LangKeys.forgotNoMailApp.tr);
  }

  void onBackToLoginTap() => NavigationUtils.backToEmailLogin();

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }
}
