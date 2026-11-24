import 'package:get/get.dart';

import '../../../../infrastructure/data_access_layer/api_repository/auth_api_repository.dart';
import '../../../../infrastructure/lang/lang_keys.g.dart';
import '../../../../infrastructure/models/api_models.g.dart';
import '../../../../infrastructure/shared/time_utils.dart';
import '../../../common_widgets/kn_confirm_dialog.dart';
import '../../../common_widgets/kn_toast.dart';

/// Me → Signed-in devices (D-146): where this account is signed in; sign one out, or all but this one
/// (a lost phone, a shared tablet). This device signs out with Log out.
class SignedInDevicesController extends GetxController {
  SignedInDevicesController({required this.auth, Future<bool> Function()? confirm, DateTime Function()? clock})
      : _confirm = confirm ?? _askFirst,
        _clock = clock ?? DateTime.now;

  final IAuthApiRepository auth;
  final Future<bool> Function() _confirm;
  final DateTime Function() _clock;

  /// null while loading.
  final Rxn<List<SignedInDeviceModel>> devices = Rxn<List<SignedInDeviceModel>>();
  final RxnString busy = RxnString(); // the device being signed out, or 'others'
  final RxBool failed = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    failed.value = false;
    final result = await auth.devices();
    final data = result.dataOrNull;
    if (data == null) {
      failed.value = true;
      devices.value = const [];
      return;
    }
    devices.value = data.data;
  }

  bool get hasOthers => (devices.value ?? const []).any((d) => !d.current);

  /// "Android phone", "iPhone", "Web browser"…
  String name(SignedInDeviceModel d) => switch (d.platform) {
        'android' => LangKeys.devicesAndroid.tr,
        'ios' => LangKeys.devicesIphone.tr,
        'ipados' => LangKeys.devicesIpad.tr,
        'macos' => LangKeys.devicesMac.tr,
        'web' => LangKeys.devicesWeb.tr,
        _ => LangKeys.devicesUnknown.tr,
      };

  /// "This device · App 1.4.0" or "Used 3 h ago · App 1.4.0".
  String line(SignedInDeviceModel d) {
    final used = d.current
        ? LangKeys.devicesThis.tr
        : LangKeys.devicesUsed.trParams({'when': TimeUtils.ago(d.lastUsedAt ?? d.signedInAt, _clock())});
    final v = d.appVersion;
    return v == null || v.isEmpty ? used : '$used · ${LangKeys.devicesApp.trParams({'version': v})}';
  }

  Future<void> onSignOutTap(SignedInDeviceModel d) async {
    if (d.current || busy.value != null) return;
    busy.value = d.id;
    final result = await auth.signOutDevice(d.id);
    busy.value = null;
    final e = result.errorOrNull;
    // already signed out elsewhere: the list just catches up
    if (e != null && e.code != 'device_not_found') return KnToast.error(e.message);
    devices.value = [...?devices.value?.where((x) => x.id != d.id)];
    KnToast.success(LangKeys.devicesSignedOut.tr);
  }

  /// "Sign out everywhere else", after asking.
  Future<void> onSignOutOthersTap() async {
    if (!hasOthers || busy.value != null || !await _confirm()) return;
    busy.value = 'others';
    final result = await auth.signOutOthers();
    busy.value = null;
    final n = result.dataOrNull;
    if (n == null) return KnToast.error(result.errorOrNull!.message);
    devices.value = [...?devices.value?.where((x) => x.current)];
    KnToast.success(LangKeys.devicesSignedOutN.trParams({'count': '$n'}));
  }

  static Future<bool> _askFirst() => showKnConfirmDialog(
        title: LangKeys.devicesOthersTitle.tr,
        body: LangKeys.devicesOthersBody.tr,
        action: LangKeys.devicesOthers.tr,
        danger: true,
      );
}
