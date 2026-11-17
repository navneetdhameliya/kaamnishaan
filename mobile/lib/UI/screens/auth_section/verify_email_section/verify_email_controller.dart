import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../infrastructure/commons/constants/app_routes.dart';
import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/services/session_service.dart';
import '../../../../infrastructure/shared/app_logger.dart';
import '../../../common_widgets/kn_toast.dart';

/// M09 Verify email (owner sign-up, step 1 of 2): the link went to the owner's email. The screen checks
/// every few seconds and moves on to Company setup by itself once the link is tapped. "Do it later"
/// goes on without it.
class VerifyEmailController extends GetxController with WidgetsBindingObserver {
  VerifyEmailController({
    required this.repository,
    required this.session,
    Future<bool> Function(Uri uri)? openUrl,
    this.checkEvery = const Duration(seconds: 5),
  }) : _openUrl = openUrl ?? ((uri) => launchUrl(uri));

  final IAuthApiRepository repository;
  final SessionService session;
  final Future<bool> Function(Uri uri) _openUrl;
  final Duration checkEvery;

  static const resendSeconds = 45;

  final RxInt secondsLeft = 0.obs;
  final RxBool resending = false.obs;
  final RxBool changing = false.obs;
  final TextEditingController newEmail = TextEditingController();
  final RxString newEmailDraft = ''.obs;
  Timer? _countdown;
  Timer? _check;
  bool _done = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    newEmail.addListener(() => newEmailDraft.value = newEmail.text);
    _startCountdown();
    _check = Timer.periodic(checkEvery, (_) => check());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    _check?.cancel();
    newEmail.dispose();
    super.onClose();
  }

  /// Back from the email app: look straight away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  String get email => session.me.value?.email ?? '';

  String get waitText {
    final s = secondsLeft.value;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _startCountdown() {
    _countdown?.cancel();
    secondsLeft.value = resendSeconds;
    _countdown = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsLeft.value <= 1) {
        secondsLeft.value = 0;
        t.cancel();
      } else {
        secondsLeft.value--;
      }
    });
  }

  /// Is the email confirmed now? Then on to Company setup.
  Future<bool> check() async {
    if (_done) return true;
    final me = (await repository.me()).dataOrNull;
    if (me == null || !me.emailVerified) return false;
    _done = true;
    session.me.value = me;
    _check?.cancel();
    KnToast.success(LangKeys.veVerified.tr);
    Get.offNamed<void>(RoutesConstants.companySetupScreen);
    return true;
  }

  Future<void> onResendTap() async {
    if (secondsLeft.value > 0 || resending.value) return;
    resending.value = true;
    final result = await repository.sendVerification();
    resending.value = false;
    if (!result.isSuccess) return KnToast.error(result.errorOrNull!.message);
    KnToast.success(LangKeys.veResent.tr);
    _startCountdown();
  }

  void startChange() => newEmail.text = email;

  /// Sends the link to the new email; true when it worked (the sheet closes).
  Future<bool> onChangeEmail() async {
    final e = newEmail.text.trim();
    if (e.isEmpty || changing.value) return false;
    changing.value = true;
    final result = await repository.changeEmail(e);
    if (!result.isSuccess) {
      changing.value = false;
      KnToast.error(result.errorOrNull!.message);
      return false;
    }
    final me = (await repository.me()).dataOrNull;
    if (me != null) session.me.value = me;
    changing.value = false;
    _startCountdown();
    return true;
  }

  /// iPhone: the Mail app's inbox. Android: the email app.
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

  /// Go on without it; the email can be confirmed any time from the link.
  void onLaterTap() => Get.toNamed<void>(RoutesConstants.companySetupScreen);
}
