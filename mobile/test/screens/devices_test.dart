import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:kaamnishaan/UI/screens/me_section/signed_in_devices_section/signed_in_devices_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_exception.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fakes.dart';

/// Toasts need the app's overlay; unit tests have none.
Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

final now = DateTime(2026, 11, 24, 15);

SignedInDeviceModel device(String id, {bool current = false, String? platform, String? version, DateTime? used}) =>
    SignedInDeviceModel(
      id: id,
      platform: platform,
      appVersion: version,
      signedInAt: DateTime(2026, 11, 1),
      lastUsedAt: used,
      current: current,
    );

void main() {
  late MockAuthRepository auth;
  var asked = 0;

  setUp(() {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    auth = MockAuthRepository();
    asked = 0;
  });

  SignedInDevicesController open(List<SignedInDeviceModel> list, {bool yes = true}) {
    when(() => auth.devices()).thenAnswer((_) async => ApiSuccess<SignedInDevicesModel>(SignedInDevicesModel(data: list)));
    return SignedInDevicesController(
      auth: auth,
      clock: () => now,
      confirm: () async {
        asked++;
        return yes;
      },
    );
  }

  test('lists this device first, then others with when they were used and the app version', () async {
    final c = open([
      device('s1', current: true, platform: 'android', version: '1.4.0'),
      device('s2', platform: 'ios', version: '1.3.2', used: now.subtract(const Duration(hours: 3))),
      device('s3', platform: 'web', used: now.subtract(const Duration(days: 2))),
    ]);
    await c.load();
    final [me, phone, web] = c.devices.value!;
    expect((c.name(me), c.line(me)), ('Android phone', 'This device · App 1.4.0'));
    expect((c.name(phone), c.line(phone)), ('iPhone', 'Used 3 h ago · App 1.3.2'));
    expect((c.name(web), c.line(web)), ('Web browser', 'Used 2 days ago'));
    expect(c.hasOthers, isTrue);
  });

  test('signs out one other device; this one is left to Log out', () async {
    final c = open([device('s1', current: true), device('s2', platform: 'ios')]);
    await c.load();
    when(() => auth.signOutDevice(any())).thenAnswer((_) async => const ApiSuccess<void>(null));
    await _ignoreApp(() => c.onSignOutTap(c.devices.value!.first));
    verifyNever(() => auth.signOutDevice(any()));
    await _ignoreApp(() => c.onSignOutTap(c.devices.value!.last));
    verify(() => auth.signOutDevice('s2')).called(1);
    expect(c.devices.value!.map((d) => d.id), ['s1']);
    expect(c.hasOthers, isFalse);
  });

  test('a device already signed out elsewhere just leaves the list', () async {
    final c = open([device('s1', current: true), device('s2')]);
    await c.load();
    when(() => auth.signOutDevice(any())).thenAnswer(
      (_) async => const ApiFailure<void>(ApiException(code: 'device_not_found', message: 'gone')),
    );
    await _ignoreApp(() => c.onSignOutTap(c.devices.value!.last));
    expect(c.devices.value!.map((d) => d.id), ['s1']);
  });

  test('"Sign out everywhere else" asks first, then keeps only this device', () async {
    final c = open([device('s1', current: true), device('s2'), device('s3')]);
    await c.load();
    when(() => auth.signOutOthers()).thenAnswer((_) async => const ApiSuccess<int>(2));
    await _ignoreApp(c.onSignOutOthersTap);
    verify(() => auth.signOutOthers()).called(1);
    expect((asked, c.devices.value!.map((d) => d.id).toList().join(',')), (1, 's1'));

    final no = open([device('s1', current: true), device('s2')], yes: false);
    await no.load();
    await _ignoreApp(no.onSignOutOthersTap);
    verifyNever(() => auth.signOutOthers());
    expect(no.devices.value!.length, 2);
  });
}
