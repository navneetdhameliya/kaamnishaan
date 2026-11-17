import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kaamnishaan/UI/screens/me_section/billing_section/billing_controller.dart';
import 'package:kaamnishaan/UI/screens/me_section/credits_section/credits_controller.dart';
import 'package:kaamnishaan/infrastructure/data_access_layer/networks/api_result.dart';
import 'package:kaamnishaan/infrastructure/lang/translation_service.dart';
import 'package:kaamnishaan/infrastructure/lang/translations.g.dart';
import 'package:kaamnishaan/infrastructure/models/api_models.g.dart';
import 'package:kaamnishaan/infrastructure/services/preferences_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

PlanOutModel plan(String code, String name, int price, {int? techs, int? reports, bool popular = false}) => PlanOutModel(
      code: code,
      name: name,
      price: MoneyModel(amount: price, currency: 'INR'),
      technicianLimit: techs,
      reportLimitMonthly: reports,
      aiQuestionsMonthly: 200,
      monthlyCredits: 300,
      mostPopular: popular,
      features: const [],
    );

final billingData = BillingOutModel(
  plan: plan('starter', 'Starter', 49900, techs: 3, reports: 60),
  status: 'active',
  periodStart: DateTime(2026, 10, 22),
  renewsAt: DateTime(2026, 11, 22),
  company: 'BrightAir Services',
  usage: const [
    UsageTileModel(key: 'technicians', used: 3, limit: 3),
    UsageTileModel(key: 'reports', used: 52, limit: 60),
    UsageTileModel(key: 'ai_questions', used: 0, limit: 200),
    UsageTileModel(key: 'credits', used: 210, limit: 300),
  ],
  upgrade: plan('professional', 'Professional', 129900, techs: 10, reports: 300, popular: true),
  paymentsReady: false,
);

final creditsData = CreditsOutModel(
  balance: 90,
  planCredits: 300,
  planUsed: 210,
  topupCredits: 0,
  plan: 'Starter',
  renewsAt: DateTime(2026, 11, 22),
  uses: const [
    CreditUseModel(kind: 'reminders', credits: 130, count: 130),
    CreditUseModel(kind: 'ai_calls', credits: 80, count: 8),
    CreditUseModel(kind: 'emails', credits: 0, count: 40),
  ],
  packs: const [
    CreditPackOutModel(id: 'p1', credits: 500, price: MoneyModel(amount: 79900, currency: 'INR')),
    CreditPackOutModel(id: 'p2', credits: 2000, price: MoneyModel(amount: 279900, currency: 'INR')),
  ],
  rules: const CreditRulesModel(sms: 1, whatsapp: 1, aiCall: 10, email: 0),
  paymentsReady: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TranslationService translation;
  late MockBillingRepository billing;

  setUpAll(() async => initializeDateFormatting());

  setUp(() async {
    Get.reset();
    Get.testMode = true;
    Get.addTranslations(KnTranslations().keys);
    Get.locale = const Locale('en', 'IN');
    SharedPreferences.setMockInitialValues({});
    translation = TranslationService(await PreferencesService.create());
    billing = MockBillingRepository();
  });

  test('M41 plan and billing: price, renewal, this month and the next plan', () async {
    when(() => billing.billing()).thenAnswer((_) async => ApiSuccess<BillingOutModel>(billingData));
    final c = BillingController(billing: billing, translation: translation);
    await c.load();
    expect((c.planName, c.periodChip, c.price), ('Starter', 'Renews 22 Nov', '₹499 / month'));
    expect([for (final u in c.usage) u.value], ['3 of 3', '52 of 60', '0 of 200', '210 of 300']);
    expect([for (final u in c.usage) u.full], [true, false, false, false]);
    expect(c.upgradeLine(c.upgrade!), '₹1,299/mo · 10 techs · 300 reports');
  });

  test('M41 follow-up credits: what is left, what used it, the packs', () async {
    when(() => billing.credits()).thenAnswer((_) async => ApiSuccess<CreditsOutModel>(creditsData));
    final c = CreditsController(billing: billing, translation: translation);
    await c.load();
    expect((c.subtitle, c.balance, c.leftLabel), ('Starter · resets on 22 Nov', '90', 'credits left of 300'));
    expect(c.fraction, closeTo(0.3, 0.001));
    expect((c.remindersValue, c.callsLabel, c.callsValue), ('130 credits', 'AI review calls · 8 calls', '80 credits'));
    expect(c.packHint(c.packs.first), '≈ 50 AI calls or 500 messages');
    expect(c.packHint(c.packs.last), 'Save 12%');
    expect(c.buyLabel, 'Buy 500 credits · ₹799');
    c.onPick('p2');
    expect(c.buyLabel, 'Buy 2000 credits · ₹2,799');
    expect(c.paymentsReady, isFalse);
  });
}
