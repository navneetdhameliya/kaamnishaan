import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/auth_section/verify_email_section/verify_email_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/plan_limit_section/plan_limit_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:kaamnishaan/infrastructure/services/session_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

Future<void> _ignoreApp(Future<void> Function() run) async {
  try {
    await run();
  } on Object catch (_) {}
}

PlanOutModel plan(String code, String name, int price, int techs, int? reports) => PlanOutModel(
      code: code,
      name: name,
      price: MoneyModel(amount: price, currency: 'INR'),
      technicianLimit: techs,
      reportLimitMonthly: reports,
      aiQuestionsMonthly: 200,
      monthlyCredits: 300,
      mostPopular: false,
      features: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TranslationService translation;
  late MockAuthRepository auth;
  late MockBillingRepository billing;
  late SessionService session;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    auth = MockAuthRepository();
    billing = MockBillingRepository();
    session = SessionService(tokens: MemoryTokenStorage(), repository: auth)..me.value = me(email: 'suresh@brightair.in');
  });

  test('M09 waits for the link, then moves on by itself', () async {
    var verified = false;
    when(() => auth.me()).thenAnswer(
      (_) async => ApiSuccess<MeOutModel>(
        MeOutModel.fromJson({...me(email: 'suresh@brightair.in').toJson(), 'email_verified': verified}),
      ),
    );
    final c = VerifyEmailController(repository: auth, session: session, checkEvery: const Duration(hours: 1));
    c.onInit();
    expect((c.email, c.secondsLeft.value, c.waitText), ('suresh@brightair.in', 45, '0:45'));
    expect(await c.check(), isFalse);
    verified = true;
    await _ignoreApp(() async => expect(await c.check(), isTrue));
    expect(session.me.value?.emailVerified, isTrue);
    c.onClose();
  });

  test('M09 change the email: the link goes to the new one', () async {
    when(() => auth.changeEmail(any())).thenAnswer((_) async => const ApiSuccess<void>(null));
    when(() => auth.me()).thenAnswer((_) async => ApiSuccess<MeOutModel>(me(email: 'suresh@brightair.example')));
    final c = VerifyEmailController(repository: auth, session: session, checkEvery: const Duration(hours: 1));
    c.onInit();
    c.startChange();
    expect(c.newEmail.text, 'suresh@brightair.in');
    c.newEmail.text = 'suresh@brightair.example';
    expect(await c.onChangeEmail(), isTrue);
    verify(() => auth.changeEmail('suresh@brightair.example')).called(1);
    expect(c.email, 'suresh@brightair.example');
    // the resend button waits again
    expect(c.secondsLeft.value, 45);
    await c.onResendTap();
    verifyNever(() => auth.sendVerification());
    c.onClose();
  });

  test('M41 plan limit: the owner is offered the next plan, others are not', () async {
    PlanStatusModel status({required bool owner}) => PlanStatusModel(
          plan: plan('starter', 'Starter', 49900, 3, 60),
          upgrade: plan('professional', 'Professional', 129900, 10, 300),
          renewsAt: DateTime(2026, 11, 22),
          reports: const UsageTileModel(key: 'reports', used: 60, limit: 60),
          technicians: const UsageTileModel(key: 'technicians', used: 3, limit: 3),
          canUpgrade: owner,
        );
    when(() => billing.plan()).thenAnswer((_) async => ApiSuccess<PlanStatusModel>(status(owner: true)));
    final c = PlanLimitController(billing: billing, translation: translation);
    await c.load();
    expect((c.title, c.resets, c.fraction), ('You used 60 of 60 reports', 'Starter · resets on 22 Nov', 1.0));
    expect(c.body, startsWith('Upgrade to keep sending reports'));
    expect((c.price(c.data.value!.plan), c.limits(c.data.value!.plan)), ('₹499\u00A0/\u00A0mo', '60 reports · 3 techs'));
    expect(c.upgradeLabel, 'Upgrade to Professional · ₹1,299');
    when(() => billing.plan()).thenAnswer((_) async => ApiSuccess<PlanStatusModel>(status(owner: false)));
    await c.load();
    expect(c.canUpgrade, isFalse);
    expect(c.body, startsWith('Your company used'));
  });
}
